/**
 * Granting / removing the `admin` custom claim. Shared by the
 * `setAdminClaim` callable and the one-time bootstrap script.
 */
import { getAuth, type UserRecord } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { Collections, UserFields, UserRole } from "../config";

/** Finds a user by email (case-insensitive, as Firebase stores emails). */
export async function findUserByEmail(email: string): Promise<UserRecord> {
  return getAuth().getUserByEmail(email.trim().toLowerCase());
}

/**
 * Sets or removes `admin: true` on the user's token, keeping any other
 * claims, and mirrors it into `users/{uid}.role` for display.
 *
 * The user's app picks up the change on its next token refresh (the app
 * forces one on start-up), or immediately after re-login.
 */
export async function setAdmin(uid: string, isAdmin: boolean): Promise<void> {
  const auth = getAuth();
  const user = await auth.getUser(uid);

  const claims: Record<string, unknown> = { ...(user.customClaims ?? {}) };
  if (isAdmin) {
    claims.admin = true;
  } else {
    delete claims.admin;
  }
  await auth.setCustomUserClaims(uid, claims);

  const profile = getFirestore().collection(Collections.users).doc(uid);
  if ((await profile.get()).exists) {
    await profile.update({
      [UserFields.role]: isAdmin ? UserRole.admin : UserRole.student,
    });
  }
}
