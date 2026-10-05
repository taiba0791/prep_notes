/**
 * Callable: an existing admin makes another user an admin (or removes it).
 *
 * Request data: { email: string, admin: boolean }
 * Response:     { uid: string, email: string, admin: boolean }
 */
import "../config";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import { findUserByEmail, setAdmin } from "./admin_claims";

interface SetAdminClaimData {
  email: string;
  admin: boolean;
}

interface SetAdminClaimResult {
  uid: string;
  email: string;
  admin: boolean;
}

function parseData(data: unknown): SetAdminClaimData {
  const d = (data ?? {}) as Record<string, unknown>;
  const email = typeof d.email === "string" ? d.email.trim() : "";
  if (!email || email.length > 320 || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid email is required.");
  }
  if (typeof d.admin !== "boolean") {
    throw new HttpsError("invalid-argument", "`admin` must be true or false.");
  }
  return { email, admin: d.admin };
}

/** The logic, exported separately so tests can call it directly. */
export async function handleSetAdminClaim(
  request: CallableRequest<unknown>,
): Promise<SetAdminClaimResult> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Only admins can do this.");
  }

  const { email, admin } = parseData(request.data);

  let target;
  try {
    target = await findUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "No account uses that email.");
  }

  // Never let an admin lock themselves out (there must always be an admin).
  if (target.uid === request.auth.uid && !admin) {
    throw new HttpsError(
      "failed-precondition",
      "You can't remove your own admin access.",
    );
  }

  await setAdmin(target.uid, admin);
  logger.info("Admin claim changed", {
    by: request.auth.uid,
    target: target.uid,
    admin,
  });
  return { uid: target.uid, email: target.email ?? email, admin };
}

export const setAdminClaim = onCall(handleSetAdminClaim);
