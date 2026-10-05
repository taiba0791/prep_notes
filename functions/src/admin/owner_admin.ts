/**
 * Owners become admin automatically.
 *
 * Trigger: any write to users/{uid} (the app creates the profile on sign-up
 * and updates lastLoginAt on every sign-in). If the account's VERIFIED email
 * is in OWNER_EMAILS and it isn't admin yet, grant admin.
 *
 * setAdmin() also writes users/{uid}.role, which fires this trigger again —
 * that second run sees the claim is already set and stops (no loop).
 */
import "../config";
import { getAuth } from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { OWNER_EMAILS, UserFields } from "../config";
import { setAdmin } from "./admin_claims";

const normalise = (email: unknown) =>
  typeof email === "string" ? email.trim().toLowerCase() : "";

/**
 * Grants admin if [uid] is an owner. Returns true if it granted admin now.
 * Exported (with an injectable owner list) for tests.
 */
export async function grantAdminIfOwner(
  uid: string,
  profileEmail: unknown,
  owners: readonly string[] = OWNER_EMAILS,
): Promise<boolean> {
  const ownerSet = new Set(owners.map(normalise));
  // Cheap check first, so ordinary students never cost an Auth lookup.
  if (!ownerSet.has(normalise(profileEmail))) return false;

  // Trust the Auth record, not the profile document.
  const user = await getAuth().getUser(uid);
  if (!ownerSet.has(normalise(user.email))) return false;
  if (!user.emailVerified) {
    logger.info("Owner email not verified yet; admin not granted", { uid });
    return false;
  }
  if (user.customClaims?.admin === true) return false;

  await setAdmin(uid, true);
  logger.info("Owner granted admin", { uid });
  return true;
}

export const onUserProfileWritten = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // deleted
    await grantAdminIfOwner(event.params.uid, after.get(UserFields.email));
  },
);
