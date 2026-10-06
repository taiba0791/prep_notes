/**
 * Callable `markOrderRefunded({ orderId, reason })` — admin only.
 *
 * RECORDS a refund the admin has made (or will make) in the Razorpay
 * Dashboard. It does NOT move money. In one transaction it:
 *  - sets the order to "refunded" (who, when, why),
 *  - removes the student's access to the note(s) bought with this order,
 *  - lowers the note's purchaseCount, the totals and today's revenue.
 * Only paid orders can be refunded; doing it twice changes nothing.
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
  EntitlementFields,
  NoteFields,
  OrderFields,
  OrderStatus,
  StatsFields,
} from "../config";
import { idFrom, requireAdmin } from "../admin/require_admin";
import { bumpDaily, bumpGlobal } from "../stats/stats";

export async function handleMarkOrderRefunded(
  request: CallableRequest<unknown>,
): Promise<{ status: "refunded" | "already-refunded"; removedNotes: string[] }> {
  const adminUid = requireAdmin(request);
  const orderId = idFrom(request.data, "orderId");
  const rawReason = (request.data as { reason?: unknown } | null)?.reason;
  const reason = typeof rawReason === "string" ? rawReason.trim().slice(0, 300) : "";

  const db = getFirestore();
  const orderRef = db.collection(Collections.orders).doc(orderId);

  const result = await db.runTransaction(async (tx) => {
    const order = await tx.get(orderRef);
    if (!order.exists) throw new HttpsError("not-found", "Order not found.");
    const status = order.get(OrderFields.status);
    if (status === OrderStatus.refunded) {
      return { status: "already-refunded" as const, removedNotes: [] };
    }
    if (status !== OrderStatus.paid) {
      throw new HttpsError("failed-precondition", "Only paid orders can be refunded.");
    }

    const uid = order.get(OrderFields.userId) as string;
    const noteIds = (order.get(OrderFields.noteIds) as string[]) ?? [];
    const amount = (order.get(OrderFields.amount) as number) ?? 0;
    const entRefs = noteIds.map((id) =>
      db.collection(Collections.users).doc(uid)
        .collection(Collections.entitlements).doc(id),
    );
    // All reads first (Firestore transactions: reads before writes).
    const ents = entRefs.length ? await tx.getAll(...entRefs) : [];
    const notes = noteIds.length
      ? await tx.getAll(...noteIds.map((id) => db.collection(Collections.notes).doc(id)))
      : [];

    // Only remove access that came from THIS order.
    const removed: string[] = [];
    ents.forEach((e, i) => {
      if (!e.exists || e.get(EntitlementFields.orderId) !== orderId) return;
      removed.push(noteIds[i]);
      tx.delete(e.ref);
      if (notes[i].exists) {
        tx.update(notes[i].ref, {
          [NoteFields.purchaseCount]: FieldValue.increment(-1),
        });
      }
    });
    tx.update(orderRef, {
      [OrderFields.status]: OrderStatus.refunded,
      [OrderFields.refundedAt]: FieldValue.serverTimestamp(),
      [OrderFields.refundedBy]: adminUid,
      [OrderFields.refundReason]: reason,
    });
    bumpGlobal(tx, {
      [StatsFields.totalPurchases]: -removed.length,
      [StatsFields.totalRevenue]: -amount,
    });
    bumpDaily(tx, { revenue: -amount, refunds: 1 });
    return { status: "refunded" as const, removedNotes: removed };
  });

  logger.info("Order refund recorded", { orderId, adminUid, ...result });
  return result;
}

export const markOrderRefunded = onCall(
  { invoker: "public" },
  handleMarkOrderRefunded,
);
