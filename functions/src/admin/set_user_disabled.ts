/**
 * Callable `setUserDisabled({ uid, disabled })` — admin only.
 *
 * A disabled account can't sign in, and its current sessions end within
 * the hour (refresh tokens are revoked). Admins can't disable themselves or
 * other admins (remove admin first). Mirrors the flag to users/{uid}.disabled
 * for the admin list.
 */
import "../config";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import { Collections, UserFields } from "../config";
import { idFrom, requireAdmin } from "./require_admin";

export async function handleSetUserDisabled(
  request: CallableRequest<unknown>,
): Promise<{ uid: string; disabled: boolean }> {
  const adminUid = requireAdmin(request);
  const uid = idFrom(request.data, "uid");
  const disabled = (request.data as { disabled?: unknown }).disabled;
  if (typeof disabled !== "boolean") {
    throw new HttpsError("invalid-argument", "`disabled` must be true or false.");
  }
  if (uid === adminUid) {
    throw new HttpsError("failed-precondition", "You can't disable your own account.");
  }

  const auth = getAuth();
  const user = await auth.getUser(uid).catch(() => {
    throw new HttpsError("not-found", "User not found.");
  });
  if (disabled && user.customClaims?.admin === true) {
    throw new HttpsError("failed-precondition", "Remove admin access first.");
  }

  await auth.updateUser(uid, { disabled });
  if (disabled) await auth.revokeRefreshTokens(uid);

  const profile = getFirestore().collection(Collections.users).doc(uid);
  if ((await profile.get()).exists) {
    await profile.update({ [UserFields.disabled]: disabled });
  }
  logger.info("User disabled flag set", { uid, disabled, by: adminUid });
  return { uid, disabled };
}

export const setUserDisabled = onCall(
  { invoker: "public" },
  handleSetUserDisabled,
);
