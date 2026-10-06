/**
 * Turning a paid order into access. Used by BOTH verifyPayment (the app
 * reports success) and razorpayWebhook (Razorpay reports success) — so it
 * must be idempotent: the second call changes nothing.
 *
 * - "note" orders: users/{uid}/entitlements/{noteId}, valid 6 months.
 * - "bundle" orders: users/{uid}/bundles/{semesterId}, valid 6 months; it
 *   unlocks every note of the semester and the Resource Room.
 */
import "../config";
import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  ACCESS_MONTHS,
  addMonths,
  BundleFields,
  Collections,
  EntitlementFields,
  NoteFields,
  OrderFields,
  OrderStatus,
  OrderType,
  SemesterFields,
  StatsFields,
  UniversityFields,
} from "../config";
import { isActive, refreshRoomAccess } from "../access/access";
import { bumpDaily, bumpGlobal } from "../stats/stats";

export type GrantResult =
  | { status: "granted"; noteIds: string[] }
  | { status: "already-paid"; noteIds: string[] }
  | { status: "not-found" }
  | { status: "amount-mismatch" };

/**
 * Marks orders/{orderId} as paid and, in the SAME transaction, gives the
 * access it pays for and updates the stats. [paidAmount] (from the webhook)
 * must equal the order amount.
 */
export async function grantOrder(
  orderId: string,
  paymentId: string,
  paidAmount?: number,
  now = new Date(),
): Promise<GrantResult> {
  const db = getFirestore();
  const orderRef = db.collection(Collections.orders).doc(orderId);
  const expiresAt = Timestamp.fromDate(addMonths(now, ACCESS_MONTHS));
  let bundleUid: string | null = null;

  const result = await db.runTransaction(async (tx): Promise<GrantResult> => {
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
    const type = order.get(OrderFields.type) ?? OrderType.note;
    let purchases = 0;

    if (type === OrderType.bundle) {
      const semesterId = order.get(OrderFields.semesterId) as string;
      const semRef = db.collection(Collections.semesters).doc(semesterId);
      const sem = await tx.get(semRef);
      const uniId = sem.get(SemesterFields.universityId) as string | undefined;
      const uni = uniId
        ? await tx.get(db.collection("universities").doc(uniId))
        : null;
      // Writes start here (all reads done).
      tx.set(userRef.collection(Collections.bundles).doc(semesterId), {
        [BundleFields.semesterId]: semesterId,
        [BundleFields.universityId]: uniId ?? "",
        [BundleFields.universityName]: uni?.get(UniversityFields.name) ?? "",
        [BundleFields.semesterNumber]: sem.get(SemesterFields.number) ?? 0,
        [BundleFields.semesterName]: sem.get(SemesterFields.name) ?? "",
        [BundleFields.orderId]: orderId,
        [BundleFields.pricePaid]: amount,
        [BundleFields.purchasedAt]: FieldValue.serverTimestamp(),
        [BundleFields.expiresAt]: expiresAt,
      });
      purchases = 1;
      bundleUid = uid;
    } else {
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
      const each = noteIds.length ? Math.round(amount / noteIds.length) : 0;
      notes.forEach((note, i) => {
        // Still active (e.g. paid twice): keep the first record.
        if (
          owned[i].exists &&
          isActive(owned[i].get(EntitlementFields.expiresAt), now.getTime())
        ) {
          return;
        }
        purchases++;
        tx.set(owned[i].ref, {
          [EntitlementFields.noteId]: noteIds[i],
          [EntitlementFields.orderId]: orderId,
          [EntitlementFields.purchasedAt]: FieldValue.serverTimestamp(),
          [EntitlementFields.expiresAt]: expiresAt,
          [EntitlementFields.pricePaid]: each,
          [EntitlementFields.title]: note.get(NoteFields.title) ?? "",
          [EntitlementFields.universityName]:
            note.get(NoteFields.universityName) ?? "",
          [EntitlementFields.semesterNumber]:
            note.get(NoteFields.semesterNumber) ?? 0,
          [EntitlementFields.subjectName]:
            note.get(NoteFields.subjectName) ?? "",
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
    }

    tx.update(orderRef, {
      [OrderFields.status]: OrderStatus.paid,
      [OrderFields.razorpayPaymentId]: paymentId,
      [OrderFields.paidAt]: FieldValue.serverTimestamp(),
      [OrderFields.failureReason]: FieldValue.delete(),
    });
    bumpGlobal(tx, {
      [StatsFields.totalPurchases]: purchases,
      [StatsFields.totalRevenue]: amount,
    });
    bumpDaily(tx, { purchases, revenue: amount });
    logger.info("Order paid", { orderId, uid, type, amount });
    return { status: "granted", noteIds };
  });

  // A bundle also opens the Resource Room.
  if (bundleUid) await refreshRoomAccess(bundleUid);
  return result;
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
