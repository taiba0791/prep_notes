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
  BundleFields,
  Collections,
  EntitlementFields,
  NoteFields,
  OrderFields,
  OrderStatus,
  OrderType,
  StatsFields,
} from "../config";
import { refreshRoomAccess } from "../access/access";
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

  let refreshUid: string | null = null;
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
    const type = order.get(OrderFields.type) ?? OrderType.note;
    const userRef = db.collection(Collections.users).doc(uid);
    const removed: string[] = [];
    let purchasesRemoved = 0;

    if (type === OrderType.bundle) {
      const semesterId = order.get(OrderFields.semesterId) as string;
      const bundleRef = userRef.collection(Collections.bundles).doc(semesterId);
      const bundle = await tx.get(bundleRef);
      if (bundle.exists && bundle.get(BundleFields.orderId) === orderId) {
        tx.delete(bundleRef);
        removed.push(`bundle:${semesterId}`);
        purchasesRemoved = 1;
        refreshUid = uid;
      }
    } else if (type === OrderType.note) {
      const entRefs = noteIds.map((id) =>
        userRef.collection(Collections.entitlements).doc(id),
      );
      // All reads first (Firestore transactions: reads before writes).
      const ents = entRefs.length ? await tx.getAll(...entRefs) : [];
      const notes = noteIds.length
        ? await tx.getAll(...noteIds.map((id) => db.collection(Collections.notes).doc(id)))
        : [];
      // Only remove access that came from THIS order.
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
      purchasesRemoved = removed.length;
    }
    // Subscription charges: only recorded here; cancel the subscription
    // itself in the Razorpay Dashboard.

    tx.update(orderRef, {
      [OrderFields.status]: OrderStatus.refunded,
      [OrderFields.refundedAt]: FieldValue.serverTimestamp(),
      [OrderFields.refundedBy]: adminUid,
      [OrderFields.refundReason]: reason,
    });
    bumpGlobal(tx, {
      [StatsFields.totalPurchases]: -purchasesRemoved,
      [StatsFields.totalRevenue]: -amount,
    });
    bumpDaily(tx, { revenue: -amount, refunds: 1 });
    return { status: "refunded" as const, removedNotes: removed };
  });

  // A refunded bundle no longer opens the Resource Room.
  if (refreshUid) await refreshRoomAccess(refreshUid);
  logger.info("Order refund recorded", { orderId, adminUid, ...result });
  return result;
}

export const markOrderRefunded = onCall(
  { invoker: "public" },
  handleMarkOrderRefunded,
);
