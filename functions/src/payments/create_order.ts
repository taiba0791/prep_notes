/**
 * Callable `createOrder({ noteId })` — step 1 of checkout.
 *
 * The PRICE COMES FROM FIRESTORE, never from the app. Refuses notes that
 * are missing, unpublished, free or already owned. Creates the Razorpay
 * order, then orders/{razorpayOrderId} with status "created".
 */
import "../config";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  Collections,
  CURRENCY_INR,
  NoteFields,
  OrderFields,
  OrderStatus,
} from "../config";
import {
  createRazorpayOrder,
  type CreateRazorpayOrder,
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
  type RazorpayKeys,
} from "./razorpay";
import { hitRateLimit } from "./rate_limit";

export interface CreateOrderResult {
  orderId: string; // Razorpay order id = our orders/{id}
  amount: number; // paise
  currency: string;
  keyId: string; // public key for Checkout
  noteTitle: string;
  email: string;
}

export interface CreateOrderDeps {
  keys: () => RazorpayKeys;
  createOrder: CreateRazorpayOrder;
}

export function makeCreateOrderHandler(deps: CreateOrderDeps) {
  return async (
    request: CallableRequest<unknown>,
  ): Promise<CreateOrderResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in.");
    }
    const uid = request.auth.uid;
    const noteId = (request.data as { noteId?: unknown } | null)?.noteId;
    if (typeof noteId !== "string" || !/^[\w-]{1,128}$/.test(noteId)) {
      throw new HttpsError("invalid-argument", "Invalid note.");
    }
    await hitRateLimit(uid, "createOrder");

    const db = getFirestore();
    const note = await db.collection(Collections.notes).doc(noteId).get();
    if (!note.exists || note.get(NoteFields.isPublished) !== true) {
      throw new HttpsError("not-found", "This note isn't available.");
    }
    const price = note.get(NoteFields.price);
    if (note.get(NoteFields.isFree) === true) {
      throw new HttpsError("failed-precondition", "free-note");
    }
    if (!Number.isInteger(price) || price < 100) {
      // Razorpay's minimum is ₹1 (100 paise).
      throw new HttpsError("failed-precondition", "Invalid price.");
    }
    const owned = await db
      .collection(Collections.users)
      .doc(uid)
      .collection(Collections.entitlements)
      .doc(noteId)
      .get();
    if (owned.exists) {
      throw new HttpsError("already-exists", "already-owned");
    }

    const keys = deps.keys();
    let rzp: { id: string };
    try {
      rzp = await deps.createOrder(
        {
          amount: price,
          currency: CURRENCY_INR,
          receipt: `pn_${Date.now()}_${uid.slice(0, 12)}`,
          notes: { uid, noteId },
        },
        keys,
      );
    } catch (e) {
      logger.error("Razorpay createOrder failed", { uid, noteId, error: `${e}` });
      throw new HttpsError("unavailable", "Payment service is busy. Try again.");
    }

    const title = (note.get(NoteFields.title) as string) ?? "";
    await db
      .collection(Collections.orders)
      .doc(rzp.id)
      .set({
        [OrderFields.userId]: uid,
        [OrderFields.noteIds]: [noteId],
        [OrderFields.noteTitles]: [title],
        [OrderFields.amount]: price,
        [OrderFields.currency]: CURRENCY_INR,
        [OrderFields.status]: OrderStatus.created,
        [OrderFields.razorpayOrderId]: rzp.id,
        [OrderFields.createdAt]: FieldValue.serverTimestamp(),
      });
    logger.info("Order created", { orderId: rzp.id, uid, noteId, price });

    return {
      orderId: rzp.id,
      amount: price,
      currency: CURRENCY_INR,
      keyId: keys.keyId,
      noteTitle: title,
      email: (request.auth.token.email as string | undefined) ?? "",
    };
  };
}

export const createOrder = onCall(
  { invoker: "public", secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  makeCreateOrderHandler({
    keys: () => ({
      keyId: RAZORPAY_KEY_ID.value(),
      keySecret: RAZORPAY_KEY_SECRET.value(),
    }),
    createOrder: createRazorpayOrder,
  }),
);
