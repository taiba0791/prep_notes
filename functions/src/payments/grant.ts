/**
 * Turning a paid order into access. Used by BOTH verifyPayment (the app
 * reports success) and razorpayWebhook (Razorpay reports success) — so it
 * must be idempotent: the second call changes nothing.
 */
import "../config";
import {
  FieldValue,
  getFirestore,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  Collections,
  EntitlementFields,
  NoteFields,
  OrderFields,
  OrderStatus,
  STATS_GLOBAL,
  StatsFields,
} from "../config";

export type GrantResult =
  | { status: "granted"; noteIds: string[] }
  | { status: "already-paid"; noteIds: string[] }
  | { status: "not-found" }
  | { status: "amount-mismatch" };

/**
 * Marks orders/{orderId} as paid and, in the SAME transaction, creates the
 * buyer's entitlements, bumps each note's purchaseCount and the global
 * stats. [paidAmount] (from the webhook) must equal the order amount.
 */
export async function grantOrder(
  orderId: string,
  paymentId: string,
  paidAmount?: number,
): Promise<GrantResult> {
  const db = getFirestore();
  const orderRef = db.collection(Collections.orders).doc(orderId);

  return db.runTransaction(async (tx): Promise<GrantResult> => {
    const order = await tx.get(orderRef);
    if (!order.exists) return { status: "not-found" };

    const noteIds = (order.get(OrderFields.noteIds) as string[]) ?? [];
    if (order.get(OrderFields.status) === OrderStatus.paid) {
      return { status: "already-paid", noteIds };
    }
    const amount = order.get(OrderFields.amount) as number;
    if (paidAmount !== undefined && paidAmount !== amount) {
      return { status: "amount-mismatch" };
    }

    const uid = order.get(OrderFields.userId) as string;
    const userRef = db.collection(Collections.users).doc(uid);
    const notes: DocumentSnapshot[] = noteIds.length
      ? await tx.getAll(
          ...noteIds.map((id) => db.collection(Collections.notes).doc(id)),
        )
      : [];
    const owned: DocumentSnapshot[] = noteIds.length
      ? await tx.getAll(
          ...noteIds.map((id) =>
            userRef.collection(Collections.entitlements).doc(id),
          ),
        )
      : [];

    // Price per note (single-note orders today: the whole amount).
    const each = noteIds.length ? Math.round(amount / noteIds.length) : 0;
    let newlyOwned = 0;
    notes.forEach((note, i) => {
      if (owned[i].exists) return; // e.g. paid twice — keep the first record
      newlyOwned++;
      tx.set(owned[i].ref, {
        [EntitlementFields.noteId]: noteIds[i],
        [EntitlementFields.orderId]: orderId,
        [EntitlementFields.purchasedAt]: FieldValue.serverTimestamp(),
        [EntitlementFields.pricePaid]: each,
        [EntitlementFields.title]: note.get(NoteFields.title) ?? "",
        [EntitlementFields.universityName]:
          note.get(NoteFields.universityName) ?? "",
        [EntitlementFields.semesterNumber]:
          note.get(NoteFields.semesterNumber) ?? 0,
        [EntitlementFields.subjectName]: note.get(NoteFields.subjectName) ?? "",
        [EntitlementFields.thumbnailUrl]:
          note.get(NoteFields.thumbnailUrl) ?? null,
        [EntitlementFields.pageCount]: note.get(NoteFields.pageCount) ?? 0,
      });
      if (note.exists) {
        tx.update(note.ref, {
          [NoteFields.purchaseCount]: FieldValue.increment(1),
        });
      }
    });

    tx.update(orderRef, {
      [OrderFields.status]: OrderStatus.paid,
      [OrderFields.razorpayPaymentId]: paymentId,
      [OrderFields.paidAt]: FieldValue.serverTimestamp(),
      [OrderFields.failureReason]: FieldValue.delete(),
    });
    tx.set(
      db.doc(STATS_GLOBAL),
      {
        [StatsFields.totalPurchases]: FieldValue.increment(newlyOwned),
        [StatsFields.totalRevenue]: FieldValue.increment(amount),
      },
      { merge: true },
    );
    logger.info("Order paid", { orderId, uid, noteIds, amount });
    return { status: "granted", noteIds };
  });
}

/** Records a failed payment, unless the order was already paid. */
export async function markOrderFailed(
  orderId: string,
  reason: string,
): Promise<void> {
  const db = getFirestore();
  const ref = db.collection(Collections.orders).doc(orderId);
  await db.runTransaction(async (tx) => {
    const order = await tx.get(ref);
    if (!order.exists || order.get(OrderFields.status) === OrderStatus.paid) {
      return;
    }
    tx.update(ref, {
      [OrderFields.status]: OrderStatus.failed,
      [OrderFields.failureReason]: reason.slice(0, 300),
    });
  });
}
