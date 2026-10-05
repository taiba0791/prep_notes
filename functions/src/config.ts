/**
 * Shared set-up. Import this FIRST in every function module so the Admin SDK
 * and global options exist before any function is defined.
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

if (getApps().length === 0) initializeApp();

// Same region as Firestore (Mumbai). maxInstances caps cost if a function
// is ever flooded with requests.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

/** Firestore collection / field names (mirror lib/core/constants/firestore_paths.dart). */
export const Collections = {
  users: "users",
} as const;

export const UserFields = {
  role: "role",
} as const;

export const UserRole = {
  student: "student",
  admin: "admin",
} as const;
