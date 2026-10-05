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

/**
 * OWNER accounts: become admin automatically after signing in, as long as
 * Google has VERIFIED the email (Google sign-in is verified immediately;
 * email/password needs the verification link clicked first).
 * Lower-case. Server-side only — the app can't see or change this list.
 */
export const OWNER_EMAILS: readonly string[] = ["prep.notes247@gmail.com"];

/** Firestore collection / field names (mirror lib/core/constants/firestore_paths.dart). */
export const Collections = {
  users: "users",
  orders: "orders",
} as const;

export const OrderFields = {
  userId: "userId",
  userDeleted: "userDeleted",
  userDeletedAt: "userDeletedAt",
} as const;

/** Default Cloud Storage bucket (lib/firebase_options.dart storageBucket). */
export const STORAGE_BUCKET = "prepnotes-635d6.firebasestorage.app";

/** Mirrors lib/core/constants/storage_paths.dart. */
export const StoragePaths = {
  avatarFolder: (uid: string) => `avatars/${uid}/`,
} as const;

export const UserFields = {
  role: "role",
  email: "email",
} as const;

export const UserRole = {
  student: "student",
  admin: "admin",
} as const;
