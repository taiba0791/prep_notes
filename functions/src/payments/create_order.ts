/**
 * Callable `createOrder({ noteId } | { semesterId })` — step 1 of checkout.
 * A note gives 6 months of access; a semester bundle gives all the
 * semester's notes + the Resource Room for 6 months.
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
  BundleFields,
  Collections,
  CURRENCY_INR,
  DEFAULT_BUNDLE_PRICE,
  NoteFields,
  OrderFields,
  OrderStatus,
  OrderType,
  SemesterFields,
  UniversityFields,
} from "../config";
import { hasNoteAccess, isActive } from "../access/access";
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
    const data = (request.data ?? {}) as { noteId?: unknown; semesterId?: unknown };
    const isId = (v: unknown): v is string =>
      typeof v === "string" && /^[\w-]{1,128}$/.test(v);
    if (!isId(data.noteId) && !isId(data.semesterId)) {
      throw new HttpsError("invalid-argument", "Invalid note.");
    }
    await hitRateLimit(uid, "createOrder");
    const db = getFirestore();
    const userRef = db.collection(Collections.users).doc(uid);

    // What is being bought, at the price stored on the SERVER.
    let item: {
      type: string;
      price: number;
      title: string;
      noteIds: string[];
      semesterId?: string;
      notes: Record<string, string>;
    };
    if (isId(data.semesterId)) {
      const semesterId = data.semesterId;
      const sem = await db.collection(Collections.semesters).doc(semesterId).get();
      if (!sem.exists || sem.get(SemesterFields.isActive) !== true) {
        throw new HttpsError("not-found", "This semester isn't available.");
      }
      const bundle = await userRef.collection(Collections.bundles).doc(semesterId).get();
      if (bundle.exists && isActive(bundle.get(BundleFields.expiresAt))) {
        throw new HttpsError("already-exists", "already-owned");
      }
      const uniId = sem.get(SemesterFields.universityId) as string;
      const uni = await db.collection("universities").doc(uniId).get();
      const raw = sem.get(SemesterFields.bundlePrice);
      item = {
        type: OrderType.bundle,
        price: raw === undefined ? DEFAULT_BUNDLE_PRICE : raw,
        title: `${uni.get(UniversityFields.name) ?? ""} · ${sem.get(SemesterFields.name) ?? ""} · Semester bundle`,
        noteIds: [],
        semesterId,
        notes: { uid, semesterId, type: OrderType.bundle },
      };
    } else {
      const noteId = data.noteId as string;
      const note = await db.collection(Collections.notes).doc(noteId).get();
      if (!note.exists || note.get(NoteFields.isPublished) !== true) {
        throw new HttpsError("not-found", "This note isn't available.");
      }
      if (note.get(NoteFields.isFree) === true) {
        throw new HttpsError("failed-precondition", "free-note");
      }
      const semesterId = note.get("semesterId") as string | undefined;
      if (await hasNoteAccess(uid, noteId, semesterId)) {
        throw new HttpsError("already-exists", "already-owned");
      }
      item = {
        type: OrderType.note,
        price: note.get(NoteFields.price),
        title: (note.get(NoteFields.title) as string) ?? "",
        noteIds: [noteId],
        notes: { uid, noteId, type: OrderType.note },
      };
    }
    if (!Number.isInteger(item.price) || item.price < 100) {
      // Razorpay's minimum is ₹1 (100 paise).
      throw new HttpsError("failed-precondition", "Invalid price.");
    }
    const price = item.price;
    const title = item.title;

    const keys = deps.keys();
    let rzp: { id: string };
    try {
      rzp = await deps.createOrder(
        {
          amount: price,
          currency: CURRENCY_INR,
          receipt: `pn_${Date.now()}_${uid.slice(0, 12)}`,
          notes: item.notes,
        },
        keys,
      );
    } catch (e) {
      logger.error("Razorpay createOrder failed", { uid, ...item.notes, error: `${e}` });
      throw new HttpsError("unavailable", "Payment service is busy. Try again.");
    }

    await db
      .collection(Collections.orders)
      .doc(rzp.id)
      .set({
        [OrderFields.userId]: uid,
        [OrderFields.type]: item.type,
        ...(item.semesterId ? { [OrderFields.semesterId]: item.semesterId } : {}),
        [OrderFields.noteIds]: item.noteIds,
        [OrderFields.noteTitles]: [title],
        [OrderFields.amount]: price,
        [OrderFields.currency]: CURRENCY_INR,
        [OrderFields.status]: OrderStatus.created,
        [OrderFields.razorpayOrderId]: rzp.id,
        [OrderFields.createdAt]: FieldValue.serverTimestamp(),
      });
    logger.info("Order created", { orderId: rzp.id, uid, ...item.notes, price });

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
