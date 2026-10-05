/**
 * Callable: the signed-in user permanently deletes their own account.
 * (Google Play requires in-app account deletion.)
 *
 * Deletes: users/{uid} + all its sub-collections, avatars/{uid}/*, the
 * Firebase Auth account. Keeps: orders (needed for accounting / refunds),
 * marked `userDeleted: true` — they hold no personal details.
 *
 * Requires a RECENT sign-in (last 5 minutes) so an unlocked phone left on a
 * desk can't be used to wipe someone's account.
 */
import "../config";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  Collections,
  OrderFields,
  STORAGE_BUCKET,
  StoragePaths,
} from "../config";

export const RECENT_LOGIN_SECONDS = 5 * 60;

/** Removes everything we store about [uid], except anonymised orders. */
export async function deleteUserData(uid: string): Promise<void> {
  const db = getFirestore();

  // 1. Keep orders, but mark them (batches of 400; Firestore allows 500).
  const orders = await db
    .collection(Collections.orders)
    .where(OrderFields.userId, "==", uid)
    .get();
  for (let i = 0; i < orders.docs.length; i += 400) {
    const batch = db.batch();
    for (const doc of orders.docs.slice(i, i + 400)) {
      batch.update(doc.ref, {
        [OrderFields.userDeleted]: true,
        [OrderFields.userDeletedAt]: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // 2. Profile + sub-collections (entitlements, recentlyViewed, studySessions).
  await db.recursiveDelete(db.collection(Collections.users).doc(uid));

  // 3. Profile photo(s).
  await getStorage()
    .bucket(STORAGE_BUCKET)
    .deleteFiles({ prefix: StoragePaths.avatarFolder(uid) });
}

export async function handleDeleteMyAccount(
  request: CallableRequest<unknown>,
): Promise<{ deleted: true }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const uid = request.auth.uid;
  const authTime = Number(request.auth.token.auth_time ?? 0);
  const now = Math.floor(Date.now() / 1000);
  if (!authTime || now - authTime > RECENT_LOGIN_SECONDS) {
    // The app re-asks for the password / Google and tries again.
    throw new HttpsError("failed-precondition", "requires-recent-login");
  }

  await deleteUserData(uid);
  await getAuth().deleteUser(uid);
  logger.info("Account deleted", { uid });
  return { deleted: true };
}

export const deleteMyAccount = onCall(
  { invoker: "public" },
  handleDeleteMyAccount,
);
