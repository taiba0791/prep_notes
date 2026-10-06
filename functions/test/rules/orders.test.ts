/**
 * Rules for orders/{orderId}, users/{uid}/entitlements and server-only
 * collections (Phase 4). Clients may only READ their own purchases.
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { beforeEach, describe, it } from "vitest";
import { setupRulesEnv } from "./helpers";

const t = setupRulesEnv();

const order = (userId: string) => ({
  userId,
  noteIds: ["n1"],
  noteTitles: ["Maths"],
  amount: 4900,
  currency: "INR",
  status: "created",
  razorpayOrderId: "order_1",
  createdAt: new Date(),
});

beforeEach(async () => {
  await t.seed("orders/order_alice", order("alice"));
  await t.seed("orders/order_bob", order("bob"));
  await t.seed("users/alice/entitlements/n1", { noteId: "n1", orderId: "order_alice" });
  await t.seed("stats/global", { totalPurchases: 1 });
  await t.seed("fileAccessLogs/l1", { userId: "alice" });
  await t.seed("rateLimits/alice_createOrder", { count: 1 });
});

describe("orders", () => {
  it("owner can read their order", async () => {
    await assertSucceeds(t.student("alice").firestore().doc("orders/order_alice").get());
  });

  it("cannot read someone else's order", async () => {
    await assertFails(t.student("alice").firestore().doc("orders/order_bob").get());
    await assertFails(t.guest().firestore().doc("orders/order_alice").get());
  });

  it("owner can list only their own orders", async () => {
    const db = t.student("alice").firestore();
    await assertSucceeds(db.collection("orders").where("userId", "==", "alice").get());
    await assertFails(db.collection("orders").get());
    await assertFails(db.collection("orders").where("userId", "==", "bob").get());
  });

  it("admin can read all orders", async () => {
    await assertSucceeds(t.admin().firestore().collection("orders").get());
  });

  it("nobody can create, change or delete an order from the app", async () => {
    const alice = t.student("alice").firestore();
    await assertFails(alice.doc("orders/fake").set(order("alice")));
    await assertFails(alice.doc("orders/order_alice").update({ status: "paid" }));
    await assertFails(alice.doc("orders/order_alice").delete());
    await assertFails(t.admin().firestore().doc("orders/x").set(order("admin1")));
  });
});

describe("entitlements", () => {
  it("owner can read; others cannot", async () => {
    await assertSucceeds(
      t.student("alice").firestore().doc("users/alice/entitlements/n1").get(),
    );
    await assertFails(
      t.student("bob").firestore().doc("users/alice/entitlements/n1").get(),
    );
  });

  it("a student cannot give themselves a note", async () => {
    await assertFails(
      t.student("bob").firestore().doc("users/bob/entitlements/n1").set({
        noteId: "n1",
        orderId: "fake",
      }),
    );
    await assertFails(
      t.student("alice").firestore().doc("users/alice/entitlements/n1").delete(),
    );
  });
});

describe("server-only collections", () => {
  for (const path of ["stats/global", "fileAccessLogs/l1", "rateLimits/alice_createOrder"]) {
    it(`${path}: no client reads or writes`, async () => {
      const alice = t.student("alice").firestore();
      await assertFails(alice.doc(path).get());
      await assertFails(alice.doc(path).set({ x: 1 }));
    });
  }
});
