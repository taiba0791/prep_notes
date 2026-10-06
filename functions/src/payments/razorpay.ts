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
