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
  statsDaily: "stats_daily",
  semesters: "semesters",
  bundles: "bundles", // users/{uid}/bundles/{semesterId}
  roomItems: "roomItems", // users/{uid}/roomItems/{itemId}
  subscriptions: "subscriptions", // subscriptions/{razorpaySubscriptionId}
  config: "config",
} as const;

/** How long a note or semester bundle stays unlocked. */
export const ACCESS_MONTHS = 6;

/** Default semester bundle price when the admin hasn't set one (₹899). */
export const DEFAULT_BUNDLE_PRICE = 89900;

/** Resource Room storage limits. */
export const ROOM_MAX_FILE_BYTES = 25 * 1024 * 1024;
export const ROOM_QUOTA_BYTES = 200 * 1024 * 1024;

/** Adds [months] calendar months to [from]. */
export function addMonths(from: Date, months: number): Date {
  const d = new Date(from.getTime());
  d.setUTCMonth(d.getUTCMonth() + months);
  return d;
}

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
  refundedAt: "refundedAt",
  refundedBy: "refundedBy",
  refundReason: "refundReason",
  type: "type", // OrderType
  semesterId: "semesterId", // bundle orders
  planKey: "planKey", // subscription charges
  subscriptionId: "subscriptionId",
  userDeleted: "userDeleted",
  userDeletedAt: "userDeletedAt",
} as const;

export const OrderType = {
  note: "note",
  bundle: "bundle",
  subscription: "subscription",
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
  expiresAt: "expiresAt",
} as const;

/** users/{uid}/bundles/{semesterId}: a semester bundle the student bought. */
export const BundleFields = {
  semesterId: "semesterId",
  universityId: "universityId",
  universityName: "universityName",
  semesterNumber: "semesterNumber",
  semesterName: "semesterName",
  orderId: "orderId",
  pricePaid: "pricePaid",
  purchasedAt: "purchasedAt",
  expiresAt: "expiresAt",
} as const;

export const SemesterFields = {
  universityId: "universityId",
  number: "number",
  name: "name",
  isActive: "isActive",
  bundlePrice: "bundlePrice", // paise
} as const;

export const UniversityFields = { name: "name" } as const;

/** subscriptions/{razorpaySubscriptionId}: a Resource Room subscription. */
export const SubscriptionFields = {
  userId: "userId",
  planKey: "planKey",
  razorpayPlanId: "razorpayPlanId",
  amount: "amount",
  status: "status", // Razorpay's: created, authenticated, active, pending, halted, cancelled, completed
  currentEnd: "currentEnd", // paid until
  cancelAtPeriodEnd: "cancelAtPeriodEnd",
  createdAt: "createdAt",
  updatedAt: "updatedAt",
} as const;

/** users/{uid}/roomItems/{itemId} */
export const RoomItemFields = {
  type: "type", // drive | youtube | file
  title: "title",
  url: "url",
  storagePath: "storagePath",
  fileName: "fileName",
  contentType: "contentType",
  sizeBytes: "sizeBytes",
  createdAt: "createdAt",
  searchKeywords: "searchKeywords",
} as const;

/** config/roomPlans: { m1: {months, price, razorpayPlanId}, m3: …, m6: … } */
export const ROOM_PLANS_DOC = "config/roomPlans";
export const RoomPlanDefaults = {
  m1: { months: 1, price: 14900 },
  m3: { months: 3, price: 39900 },
  m6: { months: 6, price: 74900 },
} as const;
export type RoomPlanKey = keyof typeof RoomPlanDefaults;

export const StatsFields = {
  totalStudents: "totalStudents",
  totalNotes: "totalNotes", // published
  totalPurchases: "totalPurchases",
  totalRevenue: "totalRevenue", // paise
  updatedAt: "updatedAt",
} as const;

/** stats_daily/{yyyy-MM-dd} (India time): sales of one day. */
export const DailyFields = {
  date: "date",
  purchases: "purchases",
  revenue: "revenue", // paise, refunds subtracted on the refund day
  refunds: "refunds",
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
  roomFolder: (uid: string) => `room/${uid}/`,
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
  name: "name",
  nameLower: "nameLower", // server-maintained, for admin search
  role: "role",
  email: "email",
  disabled: "disabled", // server-maintained mirror of the Auth flag
  roomAccessUntil: "roomAccessUntil", // server: Resource Room open until
  roomBytes: "roomBytes", // server: storage used by Room uploads
  createdAt: "createdAt",
} as const;

export const UserRole = {
  student: "student",
  admin: "admin",
} as const;
