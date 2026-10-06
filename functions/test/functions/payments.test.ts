/**
 * Phase 4 payments — createOrder, verifyPayment, razorpayWebhook,
 * getNoteFileUrl. Runs against the Firestore + Storage emulators; the
 * Razorpay API is replaced by a fake (no network, no real keys).
 */
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import type { CallableRequest } from "firebase-functions/v2/https";
import { beforeEach, describe, expect, it } from "vitest";
import { STORAGE_BUCKET } from "../../src/config";
import { makeCreateOrderHandler } from "../../src/payments/create_order";
import { handleGetNoteFileUrl } from "../../src/payments/note_file_url";
import {
  type NewRazorpayOrder,
  isValidPaymentSignature,
  signForTests,
} from "../../src/payments/razorpay";
import { makeVerifyPaymentHandler } from "../../src/payments/verify_payment";
import { handleWebhook } from "../../src/payments/webhook";

const PROJECT_ID = "prepnotes-635d6";
const KEY_ID = "rzp_test_dummy";
const KEY_SECRET = "test_secret";
const WEBHOOK_SECRET = "webhook_secret";

const db = () => getFirestore();

function req<T>(uid: string | undefined, data: T, token: Record<string, unknown> = {}) {
  return {
    data,
    auth: uid ? { uid, token: { email: `${uid}@example.com`, ...token } } : undefined,
  } as unknown as CallableRequest<unknown>;
}

// Fake Razorpay: remembers what we sent, hands out order ids.
let sent: NewRazorpayOrder[] = [];
let razorpayDown = false;
const createOrder = makeCreateOrderHandler({
  keys: () => ({ keyId: KEY_ID, keySecret: KEY_SECRET }),
  createOrder: async (order) => {
    if (razorpayDown) throw new Error("503");
    sent.push(order);
    return { id: `order_${sent.length}` };
  },
});
const verifyPayment = makeVerifyPaymentHandler(() => KEY_SECRET);

const sign = (orderId: string, paymentId: string) =>
  signForTests(KEY_SECRET, `${orderId}|${paymentId}`);

function webhook(body: unknown, secret = WEBHOOK_SECRET) {
  const raw = Buffer.from(JSON.stringify(body));
  return handleWebhook(
    {
      method: "POST",
      rawBody: raw,
      header: (n) =>
        n.toLowerCase() === "x-razorpay-signature" ? signForTests(secret, raw) : undefined,
    },
    WEBHOOK_SECRET,
  );
}

const paymentEvent = (event: string, orderId: string, amount = 4900) => ({
  event,
  payload: {
    payment: {
      entity: { id: "pay_W1", order_id: orderId, amount, error_description: "Card declined" },
    },
  },
});

const note = (o: Record<string, unknown> = {}) => ({
  title: "Engineering Maths I",
  price: 4900,
  isFree: false,
  isPublished: true,
  purchaseCount: 0,
  universityName: "University of Mumbai",
  semesterNumber: 1,
  subjectName: "Maths",
  pageCount: 40,
  ...o,
});

beforeEach(async () => {
  sent = [];
  razorpayDown = false;
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  await db().doc("notes/paid").set(note());
  await db().doc("notes/free").set(note({ isFree: true, price: 0 }));
  await db().doc("notes/draft").set(note({ isPublished: false }));
  await db().doc("notes/cheap").set(note({ price: 50 }));
  for (const id of ["paid", "free", "draft"]) {
    await getStorage()
      .bucket(STORAGE_BUCKET)
      .file(`notes_private/${id}/file.pdf`)
      .save(Buffer.from("%PDF-1.4 test"));
  }
});

describe("signatures", () => {
  it("accepts Razorpay's signature and rejects forged or swapped ones", () => {
    const good = sign("order_1", "pay_1");
    expect(isValidPaymentSignature("order_1", "pay_1", good, KEY_SECRET)).toBe(true);
    expect(isValidPaymentSignature("order_1", "pay_2", good, KEY_SECRET)).toBe(false);
    expect(isValidPaymentSignature("order_2", "pay_1", good, KEY_SECRET)).toBe(false);
    expect(isValidPaymentSignature("order_1", "pay_1", good, "other")).toBe(false);
    expect(isValidPaymentSignature("order_1", "pay_1", "", KEY_SECRET)).toBe(false);
    expect(isValidPaymentSignature("order_1", "pay_1", "abc", KEY_SECRET)).toBe(false);
  });
});

describe("createOrder", () => {
  it("needs sign-in and a valid note id", async () => {
    await expect(createOrder(req(undefined, { noteId: "paid" }))).rejects.toMatchObject({
      code: "unauthenticated",
    });
    await expect(createOrder(req("alice", { noteId: "../x" }))).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("uses the price from Firestore, ignoring anything the app sends", async () => {
    const out = await createOrder(req("alice", { noteId: "paid", amount: 1 }));
    expect(out).toMatchObject({ orderId: "order_1", amount: 4900, currency: "INR", keyId: KEY_ID });
    expect(sent[0]).toMatchObject({ amount: 4900, currency: "INR", notes: { uid: "alice", noteId: "paid" } });
    expect(sent[0].receipt.length).toBeLessThanOrEqual(40);

    const order = (await db().doc("orders/order_1").get()).data();
    expect(order).toMatchObject({
      userId: "alice",
      noteIds: ["paid"],
      amount: 4900,
      status: "created",
      razorpayOrderId: "order_1",
    });
  });

  it("refuses missing, unpublished, free, too-cheap and already-owned notes", async () => {
    const cases: Array<[string, string]> = [
      ["nope", "not-found"],
      ["draft", "not-found"],
      ["free", "failed-precondition"],
      ["cheap", "failed-precondition"],
    ];
    for (const [noteId, code] of cases) {
      await expect(createOrder(req("alice", { noteId }))).rejects.toMatchObject({ code });
    }
    await db().doc("users/alice/entitlements/paid").set({
      noteId: "paid",
      expiresAt: Timestamp.fromMillis(Date.now() + 86_400_000),
    });
    await expect(createOrder(req("alice", { noteId: "paid" }))).rejects.toMatchObject({
      code: "already-exists",
    });
    expect(sent).toHaveLength(0);
  });

  it("reports a busy payment service without creating an order", async () => {
    razorpayDown = true;
    await expect(createOrder(req("alice", { noteId: "paid" }))).rejects.toMatchObject({
      code: "unavailable",
    });
    expect((await db().collection("orders").get()).empty).toBe(true);
  });

  it("is rate limited", async () => {
    await db().doc("rateLimits/alice_createOrder").set({ windowStart: Date.now(), count: 20 });
    await expect(createOrder(req("alice", { noteId: "paid" }))).rejects.toMatchObject({
      code: "resource-exhausted",
    });
  });
});

describe("verifyPayment", () => {
  beforeEach(async () => {
    await createOrder(req("alice", { noteId: "paid" }));
  });

  it("grants the note, counts the sale and marks the order paid", async () => {
    const out = await verifyPayment(
      req("alice", { orderId: "order_1", paymentId: "pay_1", signature: sign("order_1", "pay_1") }),
    );
    expect(out).toEqual({ paid: true, noteIds: ["paid"] });

    const ent = (await db().doc("users/alice/entitlements/paid").get()).data();
    expect(ent).toMatchObject({
      noteId: "paid",
      orderId: "order_1",
      pricePaid: 4900,
      title: "Engineering Maths I",
      universityName: "University of Mumbai",
    });
    const order = (await db().doc("orders/order_1").get()).data();
    expect(order).toMatchObject({ status: "paid", razorpayPaymentId: "pay_1" });
    expect((await db().doc("notes/paid").get()).get("purchaseCount")).toBe(1);
    const stats = (await db().doc("stats/global").get()).data();
    expect(stats).toMatchObject({ totalPurchases: 1, totalRevenue: 4900 });
  });

  it("rejects a forged signature and grants nothing", async () => {
    await expect(
      verifyPayment(req("alice", { orderId: "order_1", paymentId: "pay_1", signature: "f".repeat(64) })),
    ).rejects.toMatchObject({ code: "permission-denied" });
    expect((await db().doc("users/alice/entitlements/paid").get()).exists).toBe(false);
    expect((await db().doc("orders/order_1").get()).get("status")).toBe("created");
  });

  it("someone else can't complete my order", async () => {
    await expect(
      verifyPayment(req("bob", { orderId: "order_1", paymentId: "pay_1", signature: sign("order_1", "pay_1") })),
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("app + webhook together grant exactly once", async () => {
    const data = { orderId: "order_1", paymentId: "pay_1", signature: sign("order_1", "pay_1") };
    await verifyPayment(req("alice", data));
    await verifyPayment(req("alice", data));
    expect((await webhook(paymentEvent("payment.captured", "order_1"))).body).toBe("already-paid");
    expect((await webhook(paymentEvent("order.paid", "order_1"))).body).toBe("already-paid");

    expect((await db().doc("notes/paid").get()).get("purchaseCount")).toBe(1);
    const stats = (await db().doc("stats/global").get()).data();
    expect(stats).toMatchObject({ totalPurchases: 1, totalRevenue: 4900 });
  });
});

describe("razorpayWebhook", () => {
  beforeEach(async () => {
    await createOrder(req("alice", { noteId: "paid" }));
  });

  it("rejects requests without a valid signature", async () => {
    expect((await webhook(paymentEvent("payment.captured", "order_1"), "wrong")).code).toBe(400);
    expect((await db().doc("users/alice/entitlements/paid").get()).exists).toBe(false);
  });

  it("grants access when the tab was closed before verifyPayment", async () => {
    const out = await webhook(paymentEvent("payment.captured", "order_1"));
    expect(out).toEqual({ code: 200, body: "granted" });
    expect((await db().doc("users/alice/entitlements/paid").get()).exists).toBe(true);
  });

  it("refuses when the paid amount doesn't match the order", async () => {
    const out = await webhook(paymentEvent("payment.captured", "order_1", 100));
    expect(out.body).toBe("amount-mismatch");
    expect((await db().doc("users/alice/entitlements/paid").get()).exists).toBe(false);
  });

  it("records failed payments, but never un-pays a paid order", async () => {
    await webhook(paymentEvent("payment.failed", "order_1"));
    let order = (await db().doc("orders/order_1").get()).data();
    expect(order).toMatchObject({ status: "failed", failureReason: "Card declined" });

    // A retry succeeds → paid; a late "failed" event changes nothing.
    await webhook(paymentEvent("payment.captured", "order_1"));
    await webhook(paymentEvent("payment.failed", "order_1"));
    order = (await db().doc("orders/order_1").get()).data();
    expect(order?.status).toBe("paid");
    expect(order?.failureReason).toBeUndefined();
  });

  it("ignores unknown orders and events", async () => {
    expect((await webhook(paymentEvent("payment.captured", "order_999"))).body).toBe("not-found");
    expect((await webhook(paymentEvent("refund.created", "order_1"))).body).toBe("ignored");
  });
});

describe("getNoteFileUrl", () => {
  const call = (uid: string | undefined, noteId: string, token = {}) =>
    handleGetNoteFileUrl(req(uid, { noteId }, token));

  it("refuses guests and students who haven't paid", async () => {
    await expect(call(undefined, "paid")).rejects.toMatchObject({ code: "unauthenticated" });
    await expect(call("alice", "paid")).rejects.toMatchObject({ code: "permission-denied" });
    await expect(call("alice", "draft")).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("gives a short-lived link to owners, free notes and admins — and logs it", async () => {
    await db().doc("users/alice/entitlements/paid").set({
      noteId: "paid",
      expiresAt: Timestamp.fromMillis(Date.now() + 86_400_000),
    });
    const owner = await call("alice", "paid");
    expect(owner.url).toContain(encodeURIComponent("notes_private/paid/file.pdf"));
    expect(owner.expiresInSeconds).toBe(600);
    expect((await fetch(owner.url)).status).toBe(200);

    await expect(call("bob", "free")).resolves.toHaveProperty("url");
    await expect(call("boss", "draft", { admin: true })).resolves.toHaveProperty("url");

    const logs = await db().collection("fileAccessLogs").get();
    expect(logs.docs.map((d) => d.get("reason")).sort()).toEqual(["admin", "free", "owner"]);
  });

  it("is rate limited", async () => {
    await db().doc("rateLimits/bob_noteFileUrl").set({ windowStart: Date.now(), count: 30 });
    await expect(call("bob", "free")).rejects.toMatchObject({ code: "resource-exhausted" });
  });

  it("reports a missing file", async () => {
    await db().doc("notes/nofile").set(note({ isFree: true, price: 0 }));
    await expect(call("bob", "nofile")).rejects.toMatchObject({ code: "not-found" });
  });
});
