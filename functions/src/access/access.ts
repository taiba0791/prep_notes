/**
 * Who can open what, and until when.
 *
 * - A note: users/{uid}/entitlements/{noteId}.expiresAt in the future, or an
 *   active bundle for the note's semester.
 * - The Resource Room: users/{uid}.roomAccessUntil in the future. That field
 *   is the latest end of any active bundle or Room subscription, and is
 *   recalculated by [refreshRoomAccess] whenever one of those changes.
 */
import "../config";
import {
  getFirestore,
  Timestamp,
  type Transaction,
} from "firebase-admin/firestore";
import {
  BundleFields,
  Collections,
  EntitlementFields,
  SubscriptionFields,
  UserFields,
} from "../config";

export const toMillis = (v: unknown): number =>
  v instanceof Timestamp ? v.toMillis() : v instanceof Date ? v.getTime() : 0;

/** True if [expiresAt] is in the future. Missing = expired (never "forever"). */
export const isActive = (expiresAt: unknown, now = Date.now()): boolean =>
  toMillis(expiresAt) > now;

const userRef = (uid: string) =>
  getFirestore().collection(Collections.users).doc(uid);

/** Does [uid] currently have [noteId] (own purchase or semester bundle)? */
export async function hasNoteAccess(
  uid: string,
  noteId: string,
  semesterId: string | undefined,
  now = Date.now(),
): Promise<"owner" | "bundle" | null> {
  const [ent, bundle] = await Promise.all([
    userRef(uid).collection(Collections.entitlements).doc(noteId).get(),
    semesterId
      ? userRef(uid).collection(Collections.bundles).doc(semesterId).get()
      : Promise.resolve(null),
  ]);
  if (ent.exists && isActive(ent.get(EntitlementFields.expiresAt), now)) {
    return "owner";
  }
  if (bundle?.exists && isActive(bundle.get(BundleFields.expiresAt), now)) {
    return "bundle";
  }
  return null;
}

/** Latest end of any bundle or Room subscription of [uid] (ms), or 0. */
export async function roomAccessEnd(
  uid: string,
  tx?: Transaction,
): Promise<number> {
  const db = getFirestore();
  const bundlesQ = userRef(uid).collection(Collections.bundles);
  const subsQ = db
    .collection(Collections.subscriptions)
    .where(SubscriptionFields.userId, "==", uid);
  const [bundles, subs] = tx
    ? await Promise.all([tx.get(bundlesQ), tx.get(subsQ)])
    : await Promise.all([bundlesQ.get(), subsQ.get()]);
  let end = 0;
  for (const b of bundles.docs) {
    end = Math.max(end, toMillis(b.get(BundleFields.expiresAt)));
  }
  for (const s of subs.docs) {
    end = Math.max(end, toMillis(s.get(SubscriptionFields.currentEnd)));
  }
  return end;
}

/** Writes users/{uid}.roomAccessUntil from the user's bundles + subscriptions. */
export async function refreshRoomAccess(uid: string): Promise<number> {
  const end = await roomAccessEnd(uid);
  const ref = userRef(uid);
  if ((await ref.get()).exists) {
    await ref.update({
      [UserFields.roomAccessUntil]: end ? Timestamp.fromMillis(end) : null,
    });
  }
  return end;
}
