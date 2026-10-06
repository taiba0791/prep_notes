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
  notes: "notes",
  entitlements: "entitlements",
  stats: "stats",
  fileAccessLogs: "fileAccessLogs",
  rateLimits: "rateLimits",
} as const;

export const STATS_GLOBAL = "stats/global";

export const OrderFields = {
  userId: "userId",
  noteIds: "noteIds",
  noteTitles: "noteTitles",
  amount: "amount", // paise
  currency: "currency",
  status: "status",
  razorpayOrderId: "razorpayOrderId",
  razorpayPaymentId: "razorpayPaymentId",
  createdAt: "createdAt",
  paidAt: "paidAt",
  failureReason: "failureReason",
  userDeleted: "userDeleted",
  userDeletedAt: "userDeletedAt",
} as const;

export const OrderStatus = {
  created: "created",
  paid: "paid",
  failed: "failed",
  refunded: "refunded",
} as const;

/** users/{uid}/entitlements/{noteId}: what was bought + a small copy of the note for "My Purchases". */
export const EntitlementFields = {
  noteId: "noteId",
  orderId: "orderId",
  purchasedAt: "purchasedAt",
  pricePaid: "pricePaid", // paise
  title: "title",
  universityName: "universityName",
  semesterNumber: "semesterNumber",
  subjectName: "subjectName",
  thumbnailUrl: "thumbnailUrl",
  pageCount: "pageCount",
} as const;

export const StatsFields = {
  totalPurchases: "totalPurchases",
  totalRevenue: "totalRevenue", // paise
} as const;

export const CURRENCY_INR = "INR";

/**
 * Region for Cloud STORAGE triggers. The default bucket lives in the "asia1"
 * dual-region (Tokyo + Osaka), and a storage trigger must run inside it, so
 * those functions use Tokyo. Everything else stays in Mumbai (asia-south1).
 */
export const STORAGE_TRIGGER_REGION = "asia-northeast1";

/** Default Cloud Storage bucket (lib/firebase_options.dart storageBucket). */
export const STORAGE_BUCKET = "prepnotes-635d6.firebasestorage.app";

/** Mirrors lib/core/constants/storage_paths.dart. */
export const StoragePaths = {
  avatarFolder: (uid: string) => `avatars/${uid}/`,
  notePdf: (noteId: string) => `notes_private/${noteId}/file.pdf`,
  notePreview: (noteId: string) => `notes_public/${noteId}/preview.pdf`,
  notePrivateFolder: (noteId: string) => `notes_private/${noteId}/`,
  notePublicFolder: (noteId: string) => `notes_public/${noteId}/`,
} as const;

export const NoteFields = {
  title: "title",
  price: "price", // paise
  isFree: "isFree",
  isPublished: "isPublished",
  purchaseCount: "purchaseCount",
  universityName: "universityName",
  semesterNumber: "semesterNumber",
  subjectName: "subjectName",
  thumbnailUrl: "thumbnailUrl",
  pageCount: "pageCount",
  fileSizeBytes: "fileSizeBytes",
  previewPages: "previewPages",
  hasPreview: "hasPreview",
  storagePath: "storagePath",
} as const;

export const UserFields = {
  role: "role",
  email: "email",
} as const;

export const UserRole = {
  student: "student",
  admin: "admin",
} as const;
