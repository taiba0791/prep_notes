/**
 * Callable `verifyPayment({ orderId, paymentId, signature })` — the app
 * calls this after Razorpay Checkout reports success. The signature is
 * checked with our key secret; only then is access granted.
 */
import "../config";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import { Collections, OrderFields } from "../config";
import { grantOrder } from "./grant";
import { isValidPaymentSignature, RAZORPAY_KEY_SECRET } from "./razorpay";

interface VerifyInput {
  orderId?: unknown;
  paymentId?: unknown;
  signature?: unknown;
}

const isId = (v: unknown): v is string =>
  typeof v === "string" && /^[\w-]{1,100}$/.test(v);

export function makeVerifyPaymentHandler(keySecret: () => string) {
  return async (
    request: CallableRequest<unknown>,
  ): Promise<{ paid: true; noteIds: string[] }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in.");
    }
    const { orderId, paymentId, signature } =
      (request.data as VerifyInput | null) ?? {};
    if (!isId(orderId) || !isId(paymentId) || typeof signature !== "string") {
      throw new HttpsError("invalid-argument", "Invalid payment details.");
    }

    const order = await getFirestore()
      .collection(Collections.orders)
      .doc(orderId)
      .get();
    if (!order.exists || order.get(OrderFields.userId) !== request.auth.uid) {
      throw new HttpsError("not-found", "Order not found.");
    }
    if (!isValidPaymentSignature(orderId, paymentId, signature, keySecret())) {
      logger.warn("Bad payment signature", { orderId, uid: request.auth.uid });
      throw new HttpsError("permission-denied", "Payment could not be verified.");
    }

    const result = await grantOrder(orderId, paymentId);
    if (result.status !== "granted" && result.status !== "already-paid") {
      throw new HttpsError("internal", "Payment could not be completed.");
    }
    return { paid: true, noteIds: result.noteIds };
  };
}

export const verifyPayment = onCall(
  { invoker: "public", secrets: [RAZORPAY_KEY_SECRET] },
  makeVerifyPaymentHandler(() => RAZORPAY_KEY_SECRET.value()),
);
