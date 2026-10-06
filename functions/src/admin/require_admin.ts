import { type CallableRequest, HttpsError } from "firebase-functions/v2/https";

/** Throws unless the caller is a signed-in admin; returns their uid. */
export function requireAdmin(request: CallableRequest<unknown>): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Admins only.");
  }
  return request.auth.uid;
}

/** A Firestore document id / Auth uid from request data. */
export function idFrom(data: unknown, key: string): string {
  const v = (data as Record<string, unknown> | null)?.[key];
  if (typeof v !== "string" || !/^[\w-]{1,128}$/.test(v)) {
    throw new HttpsError("invalid-argument", `Invalid ${key}.`);
  }
  return v;
}
