/**
 * Simple fixed-window rate limit per user and action, stored in
 * rateLimits/{uid}_{action} (no client access — rules deny everything).
 */
import "../config";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { Collections } from "../config";

export interface Limit {
  max: number;
  windowMs: number;
}

export const Limits = {
  createOrder: { max: 20, windowMs: 10 * 60 * 1000 },
  noteFileUrl: { max: 30, windowMs: 10 * 60 * 1000 },
} as const satisfies Record<string, Limit>;

/** Counts one call; throws `resource-exhausted` when over the limit. */
export async function hitRateLimit(
  uid: string,
  action: keyof typeof Limits,
  now = Date.now(),
): Promise<void> {
  const { max, windowMs } = Limits[action];
  const db = getFirestore();
  const ref = db.collection(Collections.rateLimits).doc(`${uid}_${action}`);
  const allowed = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const start = (doc.get("windowStart") as number | undefined) ?? 0;
    const count = (doc.get("count") as number | undefined) ?? 0;
    if (now - start >= windowMs) {
      tx.set(ref, { windowStart: now, count: 1 });
      return true;
    }
    if (count >= max) return false;
    tx.update(ref, { count: count + 1 });
    return true;
  });
  if (!allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many requests. Please wait a few minutes.",
    );
  }
}
