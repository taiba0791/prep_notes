/**
 * Phase 5 — stats triggers logic, recomputeStats, markOrderRefunded,
 * setUserDisabled. Runs against the Auth + Firestore emulators.
 */
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { beforeEach, describe, expect, it } from "vitest";
import { handleSetUserDisabled } from "../../src/admin/set_user_disabled";
import { handleMarkOrderRefunded } from "../../src/payments/refund_order";
import { grantOrder } from "../../src/payments/grant";
import { handleRecomputeStats, recompute } from "../../src/stats/recompute_stats";
import { istDay } from "../../src/stats/stats";
import {
  existenceDelta,
  onUserWritten,
  publishedDelta,
} from "../../src/stats/stats_triggers";

const PROJECT_ID = "prepnotes-635d6";
const db = () => getFirestore();

function req(data: unknown, caller?: { uid: string; admin?: boolean }) {
  return {
    data,
    auth: caller ? { uid: caller.uid, token: { admin: caller.admin === true } } : undefined,
  } as unknown as CallableRequest<unknown>;
}
const boss = { uid: "boss", admin: true };
const student = { uid: "alice" };

const snap = (data: Record<string, unknown> | null) =>
  data === null
    ? { exists: false, get: () => undefined }
    : { exists: true, get: (f: string) => data[f] };

const stats = async () => (await db().doc("stats/global").get()).data() ?? {};
const today = async () => (await db().doc(`stats_daily/${istDay()}`).get()).data() ?? {};

beforeEach(async () => {
  await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: "DELETE" },
  );
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
});

describe("helpers", () => {
  it("India-time day", () => {
    // 20:00 UTC on 6 Oct = 01:30 IST on 7 Oct.
    expect(istDay(new Date("2026-10-06T20:00:00Z"))).toBe("2026-10-07");
    expect(istDay(new Date("2026-10-06T10:00:00Z"))).toBe("2026-10-06");
  });

  it("existence and publish deltas", () => {
    expect(existenceDelta(snap(null), snap({}))).toBe(1);
    expect(existenceDelta(snap({}), snap(null))).toBe(-1);
    expect(existenceDelta(snap({}), snap({}))).toBe(0);
    const pub = { isPublished: true };
    const draft = { isPublished: false };
    expect(publishedDelta(snap(draft), snap(pub))).toBe(1);
    expect(publishedDelta(snap(pub), snap(draft))).toBe(-1);
    expect(publishedDelta(snap(pub), snap(null))).toBe(-1);
    expect(publishedDelta(snap(null), snap(draft))).toBe(0);
    expect(publishedDelta(snap(pub), snap(pub))).toBe(0);
  });
});

describe("user trigger", () => {
  it("counts students and keeps a lower-case name", async () => {
    await db().doc("users/alice").set({ name: "Alice RAO", email: "a@x.com" });
    await onUserWritten("alice", snap(null), snap({ name: "Alice RAO" }));
    expect((await db().doc("users/alice").get()).get("nameLower")).toBe("alice rao");
    expect((await stats()).totalStudents).toBe(1);

    // Already in sync → no extra write needed, count unchanged.
    await onUserWritten(
      "alice",
      snap({ name: "Alice RAO" }),
      snap({ name: "Alice RAO", nameLower: "alice rao" }),
    );
    expect((await stats()).totalStudents).toBe(1);

    await onUserWritten("alice", snap({ name: "Alice RAO" }), snap(null));
    expect((await stats()).totalStudents).toBe(0);
  });
});

async function paidOrder(id: string, uid: string, noteId: string, amount = 4900) {
  await db().doc(`notes/${noteId}`).set({ title: noteId, isPublished: true, purchaseCount: 0 });
  await db().doc(`orders/${id}`).set({
    userId: uid,
    noteIds: [noteId],
    amount,
    status: "created",
    createdAt: Timestamp.now(),
  });
  await grantOrder(id, `pay_${id}`);
}

describe("markOrderRefunded", () => {
  beforeEach(async () => {
    await paidOrder("order_1", "alice", "n1");
  });

  it("admins only", async () => {
    await expect(handleMarkOrderRefunded(req({ orderId: "order_1" }))).rejects.toMatchObject({
      code: "unauthenticated",
    });
    await expect(
      handleMarkOrderRefunded(req({ orderId: "order_1" }, student)),
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("records the refund, removes access, lowers the numbers", async () => {
    expect(await today()).toMatchObject({ purchases: 1, revenue: 4900 });
    const out = await handleMarkOrderRefunded(
      req({ orderId: "order_1", reason: "Wrong subject" }, boss),
    );
    expect(out).toEqual({ status: "refunded", removedNotes: ["n1"] });

    const order = (await db().doc("orders/order_1").get()).data();
    expect(order).toMatchObject({ status: "refunded", refundedBy: "boss", refundReason: "Wrong subject" });
    expect(order?.refundedAt).toBeDefined();
    expect((await db().doc("users/alice/entitlements/n1").get()).exists).toBe(false);
    expect((await db().doc("notes/n1").get()).get("purchaseCount")).toBe(0);
    expect(await stats()).toMatchObject({ totalPurchases: 0, totalRevenue: 0 });
    expect(await today()).toMatchObject({ revenue: 0, refunds: 1 });
  });

  it("twice = no change the second time", async () => {
    await handleMarkOrderRefunded(req({ orderId: "order_1" }, boss));
    const again = await handleMarkOrderRefunded(req({ orderId: "order_1" }, boss));
    expect(again.status).toBe("already-refunded");
    expect(await stats()).toMatchObject({ totalPurchases: 0, totalRevenue: 0 });
  });

  it("refuses unpaid or missing orders", async () => {
    await db().doc("orders/order_x").set({ userId: "alice", noteIds: ["n1"], amount: 100, status: "created" });
    await expect(
      handleMarkOrderRefunded(req({ orderId: "order_x" }, boss)),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    await expect(
      handleMarkOrderRefunded(req({ orderId: "nope" }, boss)),
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("keeps access that came from a different order", async () => {
    // The student was charged twice; the note is linked to order_1.
    await db().doc("orders/order_2").set({
      userId: "alice", noteIds: ["n1"], amount: 4900, status: "created",
    });
    await grantOrder("order_2", "pay_2");
    const out = await handleMarkOrderRefunded(req({ orderId: "order_2" }, boss));
    expect(out.removedNotes).toEqual([]);
    expect((await db().doc("users/alice/entitlements/n1").get()).exists).toBe(true);
  });
});

describe("recomputeStats", () => {
  it("admins only", async () => {
    await expect(handleRecomputeStats(req({}, student))).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("rebuilds totals and the last 30 days from real data", async () => {
    await db().doc("users/alice").set({ name: "A" });
    await db().doc("users/bob").set({ name: "B" });
    await db().doc("notes/draft").set({ isPublished: false });
    await paidOrder("order_1", "alice", "n1", 4900);
    await paidOrder("order_2", "bob", "n2", 9900);
    await db().doc("orders/order_3").set({ userId: "bob", amount: 1000, status: "failed" });
    await db().doc("stats/global").set({ totalStudents: 99, totalRevenue: 1 }); // drifted

    const out = await recompute();
    expect(out).toEqual({
      totalStudents: 2,
      totalNotes: 2,
      totalPurchases: 2,
      totalRevenue: 14800,
    });
    expect(await stats()).toMatchObject(out);
    expect(await today()).toMatchObject({ purchases: 2, revenue: 14800, refunds: 0 });
    expect((await db().collection("stats_daily").get()).size).toBe(30);
    // Old profiles get their search name.
    expect((await db().doc("users/alice").get()).get("nameLower")).toBe("a");
  });
});

describe("setUserDisabled", () => {
  beforeEach(async () => {
    await getAuth().createUser({ uid: "alice", email: "alice@example.com" });
    await getAuth().createUser({ uid: "boss", email: "boss@example.com" });
    await getAuth().createUser({ uid: "admin2", email: "a2@example.com" });
    await getAuth().setCustomUserClaims("admin2", { admin: true });
    await db().doc("users/alice").set({ name: "Alice" });
  });

  it("admins only", async () => {
    await expect(
      handleSetUserDisabled(req({ uid: "alice", disabled: true }, student)),
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("disables and enables a student", async () => {
    await handleSetUserDisabled(req({ uid: "alice", disabled: true }, boss));
    expect((await getAuth().getUser("alice")).disabled).toBe(true);
    expect((await db().doc("users/alice").get()).get("disabled")).toBe(true);

    await handleSetUserDisabled(req({ uid: "alice", disabled: false }, boss));
    expect((await getAuth().getUser("alice")).disabled).toBe(false);
    expect((await db().doc("users/alice").get()).get("disabled")).toBe(false);
  });

  it("can't disable yourself, another admin, or a missing user", async () => {
    await expect(
      handleSetUserDisabled(req({ uid: "boss", disabled: true }, boss)),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    await expect(
      handleSetUserDisabled(req({ uid: "admin2", disabled: true }, boss)),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    await expect(
      handleSetUserDisabled(req({ uid: "ghost", disabled: true }, boss)),
    ).rejects.toMatchObject({ code: "not-found" });
    await expect(
      handleSetUserDisabled(req({ uid: "alice", disabled: "yes" }, boss)),
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});
