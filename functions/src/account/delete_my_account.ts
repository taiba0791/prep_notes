/**
 * Callable: the signed-in user permanently deletes their own account.
 * (Google Play requires in-app account deletion.)
 *
 * Deletes: users/{uid} + all its sub-collections, avatars/{uid}/*, room/{uid}/*,
 * the Firebase Auth account. Cancels any Resource Room subscription. Keeps: orders (needed for accounting / refunds),
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
  SubscriptionFields,
} from "../config";
import {
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
  razorpaySubscriptionApi,
} from "../payments/razorpay";

export const RECENT_LOGIN_SECONDS = 5 * 60;

/** Cancels a Razorpay subscription right away (not at period end). */
export type CancelNow = (subscriptionId: string) => Promise<void>;

const cancelWithRazorpay: CancelNow = (id) =>
  razorpaySubscriptionApi.cancelSubscription(id, false, {
    keyId: RAZORPAY_KEY_ID.value(),
    keySecret: RAZORPAY_KEY_SECRET.value(),
  });

/** Removes everything we store about [uid], except anonymised orders. */
export async function deleteUserData(
  uid: string,
  cancelNow: CancelNow = cancelWithRazorpay,
): Promise<void> {
  const db = getFirestore();

  // 0. Stop Resource Room auto-renewal — a deleted account must never be
  //    charged again.
  const subs = await db
    .collection(Collections.subscriptions)
    .where(SubscriptionFields.userId, "==", uid)
    .get();
  for (const sub of subs.docs) {
    const status = sub.get(SubscriptionFields.status) as string;
    if (["created", "authenticated", "active", "pending", "halted"].includes(status)) {
      await cancelNow(sub.id);
    }
    await sub.ref.update({
      [SubscriptionFields.status]: "cancelled",
      [OrderFields.userDeleted]: true,
    });
  }

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

  // 3. Profile photo(s) and Resource Room uploads.
  const bucket = getStorage().bucket(STORAGE_BUCKET);
  await bucket.deleteFiles({ prefix: StoragePaths.avatarFolder(uid) });
  await bucket.deleteFiles({ prefix: StoragePaths.roomFolder(uid) });
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
  { invoker: "public", secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  handleDeleteMyAccount,
);
