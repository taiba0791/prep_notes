/**
 * Razorpay: secrets, the Orders REST API and signature checks.
 *
 * Keys are Firebase secrets — never in code or git:
 *   firebase functions:secrets:set RAZORPAY_KEY_ID
 *   firebase functions:secrets:set RAZORPAY_KEY_SECRET
 *   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
 * (Emulator: put them in functions/.secret.local, which git ignores.)
 */
import { createHmac, timingSafeEqual } from "node:crypto";
import { defineSecret } from "firebase-functions/params";

export const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
export const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");
export const RAZORPAY_WEBHOOK_SECRET = defineSecret("RAZORPAY_WEBHOOK_SECRET");

export interface RazorpayKeys {
  keyId: string;
  keySecret: string;
}

export interface NewRazorpayOrder {
  amount: number; // paise
  currency: string;
  receipt: string; // max 40 chars
  notes: Record<string, string>;
}

/** Creates an order at Razorpay; returns its id ("order_…"). */
export type CreateRazorpayOrder = (
  order: NewRazorpayOrder,
  keys: RazorpayKeys,
) => Promise<{ id: string }>;

export const createRazorpayOrder: CreateRazorpayOrder = async (
  order,
  keys,
) => {
  const auth = Buffer.from(`${keys.keyId}:${keys.keySecret}`).toString(
    "base64",
  );
  const res = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${auth}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(order),
  });
  if (!res.ok) {
    // Body may describe the problem; never contains our secret.
    throw new Error(`Razorpay order failed (${res.status}): ${await res.text()}`);
  }
  const body = (await res.json()) as { id?: unknown };
  if (typeof body.id !== "string") throw new Error("Razorpay: no order id");
  return { id: body.id };
};

/** Calls the Razorpay REST API (https://api.razorpay.com/v1/...). */
async function razorpayRequest<T>(
  method: "GET" | "POST",
  path: string,
  keys: RazorpayKeys,
  body?: unknown,
): Promise<T> {
  const auth = Buffer.from(`${keys.keyId}:${keys.keySecret}`).toString("base64");
  const res = await fetch(`https://api.razorpay.com/v1/${path}`, {
    method,
    headers: {
      "Authorization": `Basic ${auth}`,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`Razorpay ${path} failed (${res.status}): ${await res.text()}`);
  }
  return (await res.json()) as T;
}

/** The Razorpay calls used by Resource Room subscriptions (fakeable in tests). */
export interface SubscriptionApi {
  createPlan(
    plan: { months: number; amount: number; name: string },
    keys: RazorpayKeys,
  ): Promise<{ id: string }>;
  createSubscription(
    sub: { planId: string; totalCount: number; notes: Record<string, string> },
    keys: RazorpayKeys,
  ): Promise<{ id: string }>;
  cancelSubscription(
    id: string,
    atCycleEnd: boolean,
    keys: RazorpayKeys,
  ): Promise<void>;
}

export const razorpaySubscriptionApi: SubscriptionApi = {
  createPlan: ({ months, amount, name }, keys) =>
    razorpayRequest("POST", "plans", keys, {
      period: "monthly",
      interval: months,
      item: { name, amount, currency: "INR" },
    }),
  createSubscription: ({ planId, totalCount, notes }, keys) =>
    razorpayRequest("POST", "subscriptions", keys, {
      plan_id: planId,
      total_count: totalCount,
      quantity: 1,
      customer_notify: 1,
      notes,
    }),
  cancelSubscription: async (id, atCycleEnd, keys) => {
    await razorpayRequest("POST", `subscriptions/${id}/cancel`, keys, {
      cancel_at_cycle_end: atCycleEnd ? 1 : 0,
    });
  },
};

/**
 * Subscription checkout signature: HMAC_SHA256(payment_id + "|" +
 * subscription_id, key_secret) — note the order is the reverse of orders.
 */
export function isValidSubscriptionSignature(
  subscriptionId: string,
  paymentId: string,
  signature: string,
  keySecret: string,
): boolean {
  if (!subscriptionId || !paymentId || !signature || !keySecret) return false;
  return sameHex(hmacHex(keySecret, `${paymentId}|${subscriptionId}`), signature);
}

function hmacHex(secret: string, payload: string | Buffer): string {
  return createHmac("sha256", secret).update(payload).digest("hex");
}

/** Constant-time comparison of two hex strings. */
function sameHex(a: string, b: string): boolean {
  const x = Buffer.from(a, "utf8");
  const y = Buffer.from(b, "utf8");
  return x.length === y.length && timingSafeEqual(x, y);
}

/**
 * Checkout success signature: HMAC_SHA256(order_id + "|" + payment_id,
 * key_secret). Only Razorpay (and we) know the secret, so a valid signature
 * proves the payment really happened for THIS order.
 */
export function isValidPaymentSignature(
  orderId: string,
  paymentId: string,
  signature: string,
  keySecret: string,
): boolean {
  if (!orderId || !paymentId || !signature || !keySecret) return false;
  return sameHex(hmacHex(keySecret, `${orderId}|${paymentId}`), signature);
}

/** Webhook signature: HMAC_SHA256(raw request body, webhook secret). */
export function isValidWebhookSignature(
  rawBody: Buffer | string,
  signature: string,
  webhookSecret: string,
): boolean {
  if (!signature || !webhookSecret) return false;
  return sameHex(hmacHex(webhookSecret, rawBody), signature);
}

/** For tests: makes the signature Razorpay would send. */
export const signForTests = hmacHex;
