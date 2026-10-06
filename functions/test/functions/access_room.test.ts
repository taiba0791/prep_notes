/**
 * Phase 6 — 6-month access, semester bundles, Resource Room subscriptions,
 * Room uploads + expiry. Emulators: Auth, Firestore, Storage. Razorpay faked.
 */
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import type { CallableRequest } from "firebase-functions/v2/https";
import { beforeEach, describe, expect, it } from "vitest";
import { hasNoteAccess } from "../../src/access/access";
import { deleteUserData } from "../../src/account/delete_my_account";
import { STORAGE_BUCKET } from "../../src/config";
import { makeCreateOrderHandler } from "../../src/payments/create_order";
import { grantOrder } from "../../src/payments/grant";
import { handleGetNoteFileUrl } from "../../src/payments/note_file_url";
import { signForTests, type SubscriptionApi } from "../../src/payments/razorpay";
import { handleMarkOrderRefunded } from "../../src/payments/refund_order";
import { handleWebhook } from "../../src/payments/webhook";
import {
  checkRoomUpload,
  expireRoomsNow,
  parseRoomPath,
} from "../../src/room/room_files";
import {
  makeCancelRoomSubscription,
  makeCreateRoomSubscription,
  makeSetRoomPlanPrice,
  makeVerifyRoomSubscription,
} from "../../src/room/subscriptions";

const PROJECT_ID = "prepnotes-635d6";
const KEYS = { keyId: "rzp_test_x", keySecret: "secret" };
const WEBHOOK_SECRET = "webhook_secret";
const DAY = 86_400_000;
const db = () => getFirestore();
const bucket = () => getStorage().bucket(STORAGE_BUCKET);

function req(uid: string | undefined, data: unknown, token: Record<string, unknown> = {}) {
  return {
    data,
    auth: uid ? { uid, token: { email: `${uid}@x.com`, ...token } } : undefined,
  } as unknown as CallableRequest<unknown>;
}

// Fake Razorpay.
let orderSeq = 0;
const createOrder = makeCreateOrderHandler({
  keys: () => KEYS,
  createOrder: async () => ({ id: `order_${++orderSeq}` }),
});
const api = {
  plans: [] as Array<{ months: number; amount: number }>,
  subs: [] as string[],
  cancelled: [] as Array<[string, boolean]>,
  async createPlan(p: { months: number; amount: number }) {
    this.plans.push(p);
    return { id: `plan_${this.plans.length}` };
  },
  async createSubscription() {
    this.subs.push("x");
    return { id: `sub_${this.subs.length}` };
  },
  async cancelSubscription(id: string, atEnd: boolean) {
    this.cancelled.push([id, atEnd]);
  },
};
const deps = { keys: () => KEYS, api: api as unknown as SubscriptionApi };
const createSub = makeCreateRoomSubscription(deps);
const verifySub = makeVerifyRoomSubscription(() => KEYS.keySecret);
const cancelSub = makeCancelRoomSubscription(deps);
const setPrice = makeSetRoomPlanPrice(deps);

function webhook(body: unknown) {
  const raw = Buffer.from(JSON.stringify(body));
  return handleWebhook(
    {
      method: "POST",
      rawBody: raw,
      header: (n) => (n === "x-razorpay-signature" ? signForTests(WEBHOOK_SECRET, raw) : undefined),
    },
    WEBHOOK_SECRET,
  );
}

const roomUntil = async (uid: string) => {
  const v = (await db().doc(`users/${uid}`).get()).get("roomAccessUntil");
  return v instanceof Timestamp ? v.toMillis() : v;
};

beforeEach(async () => {
  orderSeq = 0;
  api.plans = [];
  api.subs = [];
  api.cancelled = [];
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  await db().doc("universities/mu").set({ name: "University of Mumbai" });
  await db().doc("semesters/s3").set({ universityId: "mu", number: 3, name: "Semester 3", isActive: true });
  await db().doc("semesters/s4").set({
    universityId: "mu", number: 4, name: "Semester 4", isActive: true, bundlePrice: 59900,
  });
  for (const [id, sem] of [["n1", "s3"], ["n2", "s3"], ["n9", "s4"]]) {
    await db().doc(`notes/${id}`).set({
      title: id, semesterId: sem, price: 4900, isFree: false, isPublished: true, purchaseCount: 0,
    });
    await bucket().file(`notes_private/${id}/file.pdf`).save(Buffer.from("%PDF"));
  }
  for (const uid of ["alice", "bob"]) {
    await db().doc(`users/${uid}`).set({ name: uid, email: `${uid}@x.com` });
  }
});

describe("single notes last 6 months", () => {
  it("grant sets an expiry ~6 months ahead; expired access can be re-bought", async () => {
    await createOrder(req("alice", { noteId: "n1" }));
    const now = new Date("2026-10-07T10:00:00Z");
    await grantOrder("order_1", "pay_1", undefined, now);
    const ent = (await db().doc("users/alice/entitlements/n1").get()).get("expiresAt") as Timestamp;
    expect(ent.toDate().toISOString()).toBe("2027-04-07T10:00:00.000Z");

    expect(await hasNoteAccess("alice", "n1", "s3", now.getTime())).toBe("owner");
    const later = new Date("2027-04-08T00:00:00Z").getTime();
    expect(await hasNoteAccess("alice", "n1", "s3", later)).toBeNull();

    // Expire it for real and buy again.
    await db().doc("users/alice/entitlements/n1").update({ expiresAt: Timestamp.fromMillis(Date.now() - DAY) });
    await expect(handleGetNoteFileUrl(req("alice", { noteId: "n1" }))).rejects.toMatchObject({
      code: "permission-denied",
    });
    await expect(createOrder(req("alice", { noteId: "n1" }))).resolves.toHaveProperty("orderId", "order_2");
    await grantOrder("order_2", "pay_2");
    expect((await db().doc("users/alice/entitlements/n1").get()).get("orderId")).toBe("order_2");
    await expect(handleGetNoteFileUrl(req("alice", { noteId: "n1" }))).resolves.toHaveProperty("url");
  });
});

describe("semester bundle", () => {
  it("default ₹899, or the semester's own price", async () => {
    const a = await createOrder(req("alice", { semesterId: "s3" }));
    expect(a.amount).toBe(89900);
    expect(a.noteTitle).toContain("Semester 3");
    const b = await createOrder(req("alice", { semesterId: "s4" }));
    expect(b.amount).toBe(59900);
    expect((await db().doc("orders/order_1").get()).data()).toMatchObject({
      type: "bundle", semesterId: "s3", noteIds: [], status: "created",
    });
  });

  it("unlocks every note of that semester + the Room, for 6 months", async () => {
    await createOrder(req("alice", { semesterId: "s3" }));
    await grantOrder("order_1", "pay_1");
    const bundle = (await db().doc("users/alice/bundles/s3").get()).data();
    expect(bundle).toMatchObject({ semesterNumber: 3, universityName: "University of Mumbai", pricePaid: 89900 });
    expect(await roomUntil("alice")).toBeGreaterThan(Date.now() + 170 * DAY);

    await expect(handleGetNoteFileUrl(req("alice", { noteId: "n2" }))).resolves.toHaveProperty("url");
    await expect(handleGetNoteFileUrl(req("alice", { noteId: "n9" }))).rejects.toMatchObject({
      code: "permission-denied",
    });
    // Notes in the bundle and the bundle itself can't be bought twice.
    await expect(createOrder(req("alice", { noteId: "n1" }))).rejects.toMatchObject({ code: "already-exists" });
    await expect(createOrder(req("alice", { semesterId: "s3" }))).rejects.toMatchObject({ code: "already-exists" });
    expect((await db().doc("stats/global").get()).data()).toMatchObject({ totalPurchases: 1, totalRevenue: 89900 });
  });

  it("refunding a bundle locks the notes and the Room", async () => {
    await createOrder(req("alice", { semesterId: "s3" }));
    await grantOrder("order_1", "pay_1");
    await handleMarkOrderRefunded(req("boss", { orderId: "order_1" }, { admin: true }));
    expect((await db().doc("users/alice/bundles/s3").get()).exists).toBe(false);
    expect(await roomUntil("alice")).toBeNull();
    await expect(handleGetNoteFileUrl(req("alice", { noteId: "n1" }))).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("refuses inactive semesters", async () => {
    await db().doc("semesters/s3").update({ isActive: false });
    await expect(createOrder(req("alice", { semesterId: "s3" }))).rejects.toMatchObject({ code: "not-found" });
  });
});

describe("Room subscriptions", () => {
  const sign = (sub: string, pay: string) => signForTests(KEYS.keySecret, `${pay}|${sub}`);

  it("create → verify → Room opens; one plan reused, no double subscription", async () => {
    const out = await createSub(req("alice", { planKey: "m1" }));
    expect(out).toMatchObject({ subscriptionId: "sub_1", amount: 14900, months: 1 });
    expect(api.plans).toEqual([{ months: 1, amount: 14900, name: "PrepNotes Resource Room · 1 month" }]);

    await expect(
      verifySub(req("alice", { subscriptionId: "sub_1", paymentId: "pay_1", signature: "bad" })),
    ).rejects.toMatchObject({ code: "permission-denied" });
    await verifySub(req("alice", { subscriptionId: "sub_1", paymentId: "pay_1", signature: sign("sub_1", "pay_1") }));

    expect((await db().doc("subscriptions/sub_1").get()).get("status")).toBe("active");
    expect(await roomUntil("alice")).toBeGreaterThan(Date.now() + 27 * DAY);
    expect((await db().doc("orders/pay_1").get()).data()).toMatchObject({
      type: "subscription", amount: 14900, status: "paid", userId: "alice",
    });
    await expect(createSub(req("alice", { planKey: "m3" }))).rejects.toMatchObject({ code: "already-exists" });

    // Bob reuses the stored plan.
    await createSub(req("bob", { planKey: "m1" }));
    expect(api.plans).toHaveLength(1);
  });

  it("renewals arrive by webhook, once per payment", async () => {
    await createSub(req("alice", { planKey: "m3" }));
    const end = Math.floor((Date.now() + 90 * DAY) / 1000);
    const charged = (pay: string, current_end: number, amount = 39900) => ({
      event: "subscription.charged",
      payload: {
        subscription: { entity: { id: "sub_1", status: "active", current_end } },
        payment: { entity: { id: pay, amount } },
      },
    });
    expect((await webhook(charged("pay_1", end))).body).toBe("charged");
    expect((await webhook(charged("pay_1", end))).body).toBe("duplicate");
    expect((await webhook(charged("pay_2", end + 90 * 86400))).body).toBe("charged");
    expect((await webhook(charged("pay_3", end, 100))).body).toBe("amount-mismatch");
    expect(await roomUntil("alice")).toBe((end + 90 * 86400) * 1000);
    expect((await db().doc("stats/global").get()).get("totalRevenue")).toBe(79800);
  });

  it("cancel: stops renewing, access stays until the paid end", async () => {
    await createSub(req("alice", { planKey: "m1" }));
    await verifySub(req("alice", { subscriptionId: "sub_1", paymentId: "pay_1", signature: sign("sub_1", "pay_1") }));
    const until = await roomUntil("alice");
    await cancelSub(req("alice", {}));
    expect(api.cancelled).toEqual([["sub_1", true]]);
    expect((await db().doc("subscriptions/sub_1").get()).get("cancelAtPeriodEnd")).toBe(true);

    await webhook({
      event: "subscription.cancelled",
      payload: { subscription: { entity: { id: "sub_1", status: "cancelled" } } },
    });
    expect((await db().doc("subscriptions/sub_1").get()).get("status")).toBe("cancelled");
    expect(await roomUntil("alice")).toBe(until);
    await expect(cancelSub(req("alice", {}))).rejects.toMatchObject({ code: "not-found" });
  });

  it("admin sets a new price → new Razorpay plan", async () => {
    await expect(setPrice(req("alice", { planKey: "m6", price: 69900 }))).rejects.toMatchObject({
      code: "permission-denied",
    });
    await expect(
      setPrice(req("boss", { planKey: "m6", price: 50 }, { admin: true })),
    ).rejects.toMatchObject({ code: "invalid-argument" });
    await setPrice(req("boss", { planKey: "m6", price: 69900 }, { admin: true }));
    expect((await db().doc("config/roomPlans").get()).get("m6")).toEqual({
      months: 6, price: 69900, razorpayPlanId: "plan_1",
    });
    const out = await createSub(req("alice", { planKey: "m6" }));
    expect(out.amount).toBe(69900);
  });

  it("deleting the account cancels auto-renew immediately", async () => {
    await createSub(req("alice", { planKey: "m1" }));
    await verifySub(req("alice", { subscriptionId: "sub_1", paymentId: "pay_1", signature: sign("sub_1", "pay_1") }));
    const cancelled: string[] = [];
    await deleteUserData("alice", async (id) => {
      cancelled.push(id);
    });
    expect(cancelled).toEqual(["sub_1"]);
    expect((await db().doc("subscriptions/sub_1").get()).get("status")).toBe("cancelled");
  });
});

describe("Room files and expiry", () => {
  it("parses Room paths", () => {
    expect(parseRoomPath("room/alice/i1/notes.pdf")).toEqual({ uid: "alice", itemId: "i1" });
    expect(parseRoomPath("room/alice/notes.pdf")).toBeNull();
    expect(parseRoomPath("notes_private/n1/file.pdf")).toBeNull();
  });

  it("rejects files over the size or quota limits; tracks usage", async () => {
    const put = async (item: string, bytes: number) => {
      await db().doc(`users/alice/roomItems/${item}`).set({ type: "file" });
      await bucket().file(`room/alice/${item}/f.pdf`).save(Buffer.alloc(bytes));
    };
    await put("i1", 40);
    expect(await checkRoomUpload("room/alice/i1/f.pdf", 40, { file: 50, quota: 100 })).toBe("ok");
    expect((await db().doc("users/alice").get()).get("roomBytes")).toBe(40);

    await put("i2", 60);
    expect(await checkRoomUpload("room/alice/i2/f.pdf", 60, { file: 50, quota: 100 })).toBe("too-big");
    expect((await bucket().file("room/alice/i2/f.pdf").exists())[0]).toBe(false);
    expect((await db().doc("users/alice/roomItems/i2").get()).exists).toBe(false);

    await put("i3", 45);
    await put("i4", 45);
    expect(await checkRoomUpload("room/alice/i4/f.pdf", 45, { file: 50, quota: 100 })).toBe("over-quota");
    expect((await db().doc("users/alice").get()).get("roomBytes")).toBe(85);
  });

  it("expired Rooms are emptied; renewed ones just move their date", async () => {
    const past = Timestamp.fromMillis(Date.now() - DAY);
    await db().doc("users/alice").update({ roomAccessUntil: past });
    await db().doc("users/alice/roomItems/i1").set({ type: "file" });
    await bucket().file("room/alice/i1/f.pdf").save(Buffer.from("x"));

    await db().doc("users/bob").update({ roomAccessUntil: past });
    await db().doc("users/bob/roomItems/i1").set({ type: "youtube" });
    await db().doc("subscriptions/sub_9").set({
      userId: "bob", status: "active", currentEnd: Timestamp.fromMillis(Date.now() + 10 * DAY),
    });

    expect(await expireRoomsNow()).toEqual(["alice"]);
    expect((await db().collection("users/alice/roomItems").get()).empty).toBe(true);
    expect((await bucket().file("room/alice/i1/f.pdf").exists())[0]).toBe(false);
    expect(await roomUntil("alice")).toBeNull();

    expect((await db().doc("users/bob/roomItems/i1").get()).exists).toBe(true);
    expect(await roomUntil("bob")).toBeGreaterThan(Date.now());
  });
});
