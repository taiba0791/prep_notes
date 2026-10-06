/**
 * Callable `recomputeStats()` — admin only. Rebuilds stats/global from the
 * real data and the last 30 days of stats_daily from paid orders. Safe to
 * run any time (it overwrites, never adds).
 *
 * Orders hold one note each today, so purchases = paid orders.
 */
import "../config";
import {
  AggregateField,
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { type CallableRequest, onCall } from "firebase-functions/v2/https";
import {
  Collections,
  DailyFields,
  NoteFields,
  OrderFields,
  OrderStatus,
  StatsFields,
  UserFields,
} from "../config";
import { requireAdmin } from "../admin/require_admin";
import { dailyStatsRef, globalStatsRef, istDay } from "./stats";

export const DAYS = 30;

export interface RecomputeResult {
  totalStudents: number;
  totalNotes: number;
  totalPurchases: number;
  totalRevenue: number;
}

export async function recompute(now = new Date()): Promise<RecomputeResult> {
  const db = getFirestore();
  const paid = db
    .collection(Collections.orders)
    .where(OrderFields.status, "==", OrderStatus.paid);

  const [students, notes, sales] = await Promise.all([
    db.collection(Collections.users).count().get(),
    db
      .collection(Collections.notes)
      .where(NoteFields.isPublished, "==", true)
      .count()
      .get(),
    paid
      .aggregate({
        count: AggregateField.count(),
        revenue: AggregateField.sum(OrderFields.amount),
      })
      .get(),
  ]);
  const result: RecomputeResult = {
    totalStudents: students.data().count,
    totalNotes: notes.data().count,
    totalPurchases: sales.data().count,
    totalRevenue: sales.data().revenue ?? 0,
  };
  await globalStatsRef().set({
    ...result,
    [StatsFields.updatedAt]: FieldValue.serverTimestamp(),
  });

  // Last 30 days, grouped by the India-time day of payment.
  const days = new Map<string, { purchases: number; revenue: number }>();
  for (let i = 0; i < DAYS; i++) {
    days.set(istDay(new Date(now.getTime() - i * 86_400_000)), {
      purchases: 0,
      revenue: 0,
    });
  }
  const since = Timestamp.fromMillis(now.getTime() - DAYS * 86_400_000);
  const recent = await paid.where(OrderFields.paidAt, ">=", since).get();
  for (const o of recent.docs) {
    const at = o.get(OrderFields.paidAt) as Timestamp | undefined;
    const day = at ? days.get(istDay(at.toDate())) : undefined;
    if (!day) continue;
    day.purchases += 1;
    day.revenue += (o.get(OrderFields.amount) as number) ?? 0;
  }
  const batch = db.batch();
  for (const [date, v] of days) {
    batch.set(dailyStatsRef(date), {
      [DailyFields.date]: date,
      [DailyFields.purchases]: v.purchases,
      [DailyFields.revenue]: v.revenue,
      [DailyFields.refunds]: 0,
    });
  }
  await batch.commit();
  await backfillNameLower();
  logger.info("Stats recomputed", { ...result });
  return result;
}

/** Adds the search name to profiles made before it existed (500 at a time). */
export async function backfillNameLower(): Promise<number> {
  const db = getFirestore();
  let fixed = 0;
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db.collection(Collections.users).orderBy("__name__").limit(500);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    if (page.empty) break;
    const batch = db.batch();
    for (const d of page.docs) {
      const name = d.get(UserFields.name);
      const lower = typeof name === "string" ? name.trim().toLowerCase() : "";
      if (d.get(UserFields.nameLower) !== lower) {
        batch.update(d.ref, { [UserFields.nameLower]: lower });
        fixed++;
      }
    }
    await batch.commit();
    last = page.docs[page.docs.length - 1];
  }
  return fixed;
}

export async function handleRecomputeStats(
  request: CallableRequest<unknown>,
): Promise<RecomputeResult> {
  requireAdmin(request);
  return recompute();
}

export const recomputeStats = onCall(
  { invoker: "public", timeoutSeconds: 300 },
  handleRecomputeStats,
);
