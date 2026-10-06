/**
 * Dashboard counters. stats/global holds the totals; stats_daily/{day}
 * holds one day's sales (India time) for the 30-day revenue chart.
 * Only Cloud Functions write these; admins read them.
 */
import "../config";
import {
  FieldValue,
  getFirestore,
  type Transaction,
} from "firebase-admin/firestore";
import { Collections, DailyFields, STATS_GLOBAL } from "../config";

/** "2026-10-06" for [date] in India Standard Time (UTC+5:30). */
export function istDay(date: Date = new Date()): string {
  const ist = new Date(date.getTime() + 330 * 60 * 1000);
  return ist.toISOString().slice(0, 10);
}

export const globalStatsRef = () => getFirestore().doc(STATS_GLOBAL);

export const dailyStatsRef = (day: string) =>
  getFirestore().collection(Collections.statsDaily).doc(day);

/** Adds to stats/global (merge, so the doc may not exist yet). */
export function bumpGlobal(
  tx: Transaction,
  changes: Record<string, number>,
): void {
  const data: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(changes)) {
    if (v !== 0) data[k] = FieldValue.increment(v);
  }
  if (Object.keys(data).length) {
    tx.set(globalStatsRef(), data, { merge: true });
  }
}

/** Adds to today's stats_daily document. */
export function bumpDaily(
  tx: Transaction,
  changes: { purchases?: number; revenue?: number; refunds?: number },
  day: string = istDay(),
): void {
  tx.set(
    dailyStatsRef(day),
    {
      [DailyFields.date]: day,
      [DailyFields.purchases]: FieldValue.increment(changes.purchases ?? 0),
      [DailyFields.revenue]: FieldValue.increment(changes.revenue ?? 0),
      [DailyFields.refunds]: FieldValue.increment(changes.refunds ?? 0),
    },
    { merge: true },
  );
}
