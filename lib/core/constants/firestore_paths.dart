/// Every Firestore collection, document path, field name and stored value.
///
/// No other file may type these strings by hand (see CLAUDE.md).
/// Must stay in sync with `firestore.rules` and the Cloud Functions.
///
/// MONEY: every amount (`price`, `pricePaid`, `amount`, `totalRevenue`) is an
/// integer in PAISE (₹49.00 → 4900), matching Razorpay and avoiding
/// floating-point rounding errors.
library;

// ───────────────────────────── Collections ─────────────────────────────

abstract final class FirestoreCollections {
  static const users = 'users';
  static const universities = 'universities';
  static const semesters = 'semesters';
  static const subjects = 'subjects';
  static const modules = 'modules';
  static const notes = 'notes';
  static const orders = 'orders';
  static const resourceCategories = 'resourceCategories';
  static const resources = 'resources';
  static const feedback = 'feedback';
  static const stats = 'stats';
  static const statsDaily = 'stats_daily';
  static const subscriptions = 'subscriptions';
  static const config = 'config';

  // Sub-collections of users/{uid}
  static const entitlements = 'entitlements';
  static const recentlyViewed = 'recentlyViewed';
  static const studySessions = 'studySessions';
  static const bundles = 'bundles';
  static const roomItems = 'roomItems';
}

/// Full document / collection paths.
abstract final class FirestorePaths {
  static String user(String uid) => '${FirestoreCollections.users}/$uid';

  /// WRITTEN ONLY BY CLOUD FUNCTIONS.
  static String entitlements(String uid) =>
      '${user(uid)}/${FirestoreCollections.entitlements}';
  static String entitlement(String uid, String noteId) =>
      '${entitlements(uid)}/$noteId';

  /// Semester bundles — WRITTEN ONLY BY CLOUD FUNCTIONS.
  static String bundles(String uid) =>
      '${user(uid)}/${FirestoreCollections.bundles}';
  static String bundle(String uid, String semesterId) =>
      '${bundles(uid)}/$semesterId';

  /// The student's private Resource Room items.
  static String roomItems(String uid) =>
      '${user(uid)}/${FirestoreCollections.roomItems}';
  static String roomItem(String uid, String itemId) =>
      '${roomItems(uid)}/$itemId';

  static String recentlyViewed(String uid) =>
      '${user(uid)}/${FirestoreCollections.recentlyViewed}';
  static String studySessions(String uid) =>
      '${user(uid)}/${FirestoreCollections.studySessions}';

  static String university(String id) =>
      '${FirestoreCollections.universities}/$id';
  static String semester(String id) => '${FirestoreCollections.semesters}/$id';
  static String subject(String id) => '${FirestoreCollections.subjects}/$id';
  static String module(String id) => '${FirestoreCollections.modules}/$id';
  static String note(String id) => '${FirestoreCollections.notes}/$id';

  /// WRITTEN ONLY BY CLOUD FUNCTIONS.
  static String order(String id) => '${FirestoreCollections.orders}/$id';

  static String resourceCategory(String id) =>
      '${FirestoreCollections.resourceCategories}/$id';
  static String resource(String id) => '${FirestoreCollections.resources}/$id';
  static String feedback(String id) => '${FirestoreCollections.feedback}/$id';

  /// Room subscriptions — WRITTEN ONLY BY CLOUD FUNCTIONS.
  static String subscription(String id) =>
      '${FirestoreCollections.subscriptions}/$id';

  /// Resource Room plan prices (public read, written by Cloud Functions).
  static const roomPlans = '${FirestoreCollections.config}/roomPlans';

  /// Aggregate counters, maintained by Cloud Functions.
  static const statsGlobal = '${FirestoreCollections.stats}/global';

  /// One day's sales, id "yyyy-MM-dd" (India time). Admin read only.
  static String statsDay(String day) =>
      '${FirestoreCollections.statsDaily}/$day';
}

// ─────────────────────────── Common fields ────────────────────────────

/// Fields shared by many collections.
abstract final class CommonFields {
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const isActive = 'isActive';
  static const order = 'order'; // manual sort position
  static const tags = 'tags';
  static const searchKeywords = 'searchKeywords';
}

// ─────────────────────────── Field names ──────────────────────────────

/// users/{uid}
abstract final class UserFields {
  static const name = 'name';
  static const email = 'email';
  static const photoUrl = 'photoUrl';
  static const universityId = 'universityId';
  static const semester = 'semester';

  /// Mirror only — the real admin check is the `admin` custom claim.
  static const role = 'role';
  static const totalStudyMinutes = 'totalStudyMinutes';
  static const createdAt = CommonFields.createdAt;
  static const lastLoginAt = 'lastLoginAt';

  // Written ONLY by Cloud Functions (never part of the app's profile writes).
  static const nameLower = 'nameLower'; // admin search
  static const disabled = 'disabled'; // mirror of the Auth "disabled" flag
  static const roomAccessUntil = 'roomAccessUntil'; // Room open until
  static const roomBytes = 'roomBytes'; // Room uploads, bytes used
}

/// users/{uid}/entitlements/{noteId} — written ONLY by Cloud Functions.
abstract final class EntitlementFields {
  static const noteId = 'noteId';
  static const orderId = 'orderId';
  static const purchasedAt = 'purchasedAt';
  static const pricePaid = 'pricePaid'; // paise
  static const expiresAt = 'expiresAt'; // access ends (6 months)
  // A small copy of the note, so "My Purchases" needs no extra reads.
  static const title = 'title';
  static const universityName = 'universityName';
  static const semesterNumber = 'semesterNumber';
  static const subjectName = 'subjectName';
  static const thumbnailUrl = 'thumbnailUrl';
  static const pageCount = 'pageCount';
}

/// users/{uid}/recentlyViewed/{noteId} — owner only, capped at 20.
/// Holds a small copy of the note so the list needs no extra reads.
abstract final class RecentlyViewedFields {
  static const noteId = 'noteId';
  static const viewedAt = 'viewedAt';
  static const title = 'title';
  static const universityName = 'universityName';
  static const semesterNumber = 'semesterNumber';
  static const subjectName = 'subjectName';
  static const price = 'price'; // paise
  static const isFree = 'isFree';
  static const thumbnailUrl = 'thumbnailUrl';
  static const pageCount = 'pageCount';
}

/// users/{uid}/studySessions/{sessionId}
abstract final class StudySessionFields {
  static const type = 'type';
  static const durationSec = 'durationSec';
  static const startedAt = 'startedAt';
}

/// universities/{universityId}
abstract final class UniversityFields {
  static const name = 'name';
  static const shortName = 'shortName';
  static const city = 'city';
  static const logoUrl = 'logoUrl';
  static const description = 'description';
  static const isActive = CommonFields.isActive;
  static const order = CommonFields.order;
}

/// semesters/{semesterId}
abstract final class SemesterFields {
  static const universityId = 'universityId';
  static const number = 'number';
  static const name = 'name';
  static const isActive = CommonFields.isActive;

  /// Semester bundle price in paise (missing = AccessRules.defaultBundlePrice).
  static const bundlePrice = 'bundlePrice';
}

/// subjects/{subjectId}
abstract final class SubjectFields {
  static const universityId = 'universityId';
  static const semesterId = 'semesterId';
  static const name = 'name';
  static const code = 'code';
  static const description = 'description';
  static const isActive = CommonFields.isActive;
}

/// modules/{moduleId}
abstract final class ModuleFields {
  static const subjectId = 'subjectId';
  static const number = 'number';
  static const title = 'title';
  static const isActive = CommonFields.isActive;
}

/// notes/{noteId}
abstract final class NoteFields {
  static const title = 'title';
  static const description = 'description';
  static const universityId = 'universityId';
  static const semesterId = 'semesterId';
  static const subjectId = 'subjectId';
  static const moduleId = 'moduleId';

  // Denormalized copies for fast list screens
  static const universityName = 'universityName';
  static const subjectName = 'subjectName';
  static const moduleTitle = 'moduleTitle';
  static const semesterNumber = 'semesterNumber';

  static const price = 'price'; // paise
  static const isFree = 'isFree';
  static const thumbnailUrl = 'thumbnailUrl';
  static const pageCount = 'pageCount';
  static const fileSizeBytes = 'fileSizeBytes';

  /// Private Storage path; clients can never read it directly.
  static const storagePath = 'storagePath';
  static const previewPages = 'previewPages';

  /// Set by Cloud Functions once preview.pdf exists.
  static const hasPreview = 'hasPreview';
  static const isPublished = 'isPublished';

  /// Admin flag: show first in "Popular this week" on Home.
  static const isFeatured = 'isFeatured';
  static const purchaseCount = 'purchaseCount';
  static const tags = CommonFields.tags;
  static const searchKeywords = CommonFields.searchKeywords;
  static const createdAt = CommonFields.createdAt;
  static const updatedAt = CommonFields.updatedAt;
}

/// orders/{orderId} — written ONLY by Cloud Functions.
abstract final class OrderFields {
  static const userId = 'userId';
  static const noteIds = 'noteIds';
  static const noteTitles = 'noteTitles';
  static const amount = 'amount'; // paise
  static const currency = 'currency';
  static const status = 'status'; // see OrderStatus
  static const razorpayOrderId = 'razorpayOrderId';
  static const razorpayPaymentId = 'razorpayPaymentId';
  static const createdAt = CommonFields.createdAt;
  static const paidAt = 'paidAt';
  static const failureReason = 'failureReason';
  static const refundedAt = 'refundedAt';
  static const refundedBy = 'refundedBy';
  static const refundReason = 'refundReason';
  static const type = 'type'; // see OrderType
  static const semesterId = 'semesterId'; // bundle orders
  static const planKey = 'planKey'; // Room subscription charges
  static const subscriptionId = 'subscriptionId';
}

/// users/{uid}/bundles/{semesterId} — written ONLY by Cloud Functions.
abstract final class BundleFields {
  static const semesterId = 'semesterId';
  static const universityId = 'universityId';
  static const universityName = 'universityName';
  static const semesterNumber = 'semesterNumber';
  static const semesterName = 'semesterName';
  static const orderId = 'orderId';
  static const pricePaid = 'pricePaid'; // paise
  static const purchasedAt = 'purchasedAt';
  static const expiresAt = 'expiresAt';
}

/// subscriptions/{razorpaySubscriptionId} — written ONLY by Cloud Functions.
abstract final class SubscriptionFields {
  static const userId = 'userId';
  static const planKey = 'planKey';
  static const amount = 'amount'; // paise per period
  static const status = 'status';
  static const currentEnd = 'currentEnd';
  static const cancelAtPeriodEnd = 'cancelAtPeriodEnd';
  static const createdAt = CommonFields.createdAt;
}

/// users/{uid}/roomItems/{itemId} — the student's own Resource Room.
abstract final class RoomItemFields {
  static const type = 'type'; // see RoomItemType
  static const title = 'title';
  static const url = 'url';
  static const storagePath = 'storagePath';
  static const fileName = 'fileName';
  static const contentType = 'contentType';
  static const sizeBytes = 'sizeBytes';
  static const createdAt = CommonFields.createdAt;
  static const searchKeywords = CommonFields.searchKeywords;
}

/// resourceCategories/{categoryId}
abstract final class ResourceCategoryFields {
  static const name = 'name';
  static const icon = 'icon';
  static const order = CommonFields.order;
}

/// resources/{resourceId}
abstract final class ResourceFields {
  static const title = 'title';
  static const description = 'description';
  static const categoryId = 'categoryId';
  static const type = 'type'; // see ResourceType
  static const url = 'url';
  static const storagePath = 'storagePath';
  static const tags = CommonFields.tags;
  static const isActive = CommonFields.isActive;
  static const createdAt = CommonFields.createdAt;
}

/// feedback/{feedbackId}
abstract final class FeedbackFields {
  static const type = 'type'; // see FeedbackType
  static const subType = 'subType'; // see FeedbackSubType
  static const title = 'title';
  static const message = 'message';
  static const userId = 'userId';
  static const userEmail = 'userEmail';
  static const universityRef = 'universityRef';
  static const subjectName = 'subjectName';
  static const moduleName = 'moduleName';
  static const status = 'status'; // see FeedbackStatus
  static const adminNote = 'adminNote';
  static const createdAt = CommonFields.createdAt;
  static const updatedAt = CommonFields.updatedAt;
}

/// stats/global — maintained by Cloud Functions.
abstract final class StatsFields {
  static const totalStudents = 'totalStudents';
  static const totalNotes = 'totalNotes';
  static const totalPurchases = 'totalPurchases';
  static const totalRevenue = 'totalRevenue'; // paise
}

/// stats_daily/{yyyy-MM-dd} — maintained by Cloud Functions.
abstract final class DailyStatsFields {
  static const date = 'date';
  static const purchases = 'purchases';
  static const revenue = 'revenue'; // paise; refunds subtracted that day
  static const refunds = 'refunds';
}

// ─────────────────────────── Stored values ────────────────────────────

abstract final class UserRole {
  static const student = 'student';
  static const admin = 'admin';
}

abstract final class OrderType {
  static const note = 'note';
  static const bundle = 'bundle';
  static const subscription = 'subscription';
}

abstract final class RoomItemType {
  static const drive = 'drive';
  static const youtube = 'youtube';
  static const file = 'file';
}

/// Access rules (must match functions/src/config.ts).
abstract final class AccessRules {
  /// Notes and semester bundles stay unlocked this long.
  static const months = 6;

  /// Semester bundle price when the admin hasn't set one (₹899).
  static const defaultBundlePrice = 89900;
  static const roomMaxFileBytes = 25 * 1024 * 1024;
  static const roomQuotaBytes = 200 * 1024 * 1024;

  /// Warn this many days before Room access (and its items) ends.
  static const roomWarningDays = 14;
}

abstract final class OrderStatus {
  static const created = 'created';
  static const paid = 'paid';
  static const failed = 'failed';
  static const refunded = 'refunded';
}

abstract final class ResourceType {
  static const link = 'link';
  static const file = 'file';
}

abstract final class FeedbackType {
  static const featureProblem = 'feature_problem';
  static const notesRequest = 'notes_request';
  static const general = 'general';
}

/// Phase 7 may add more sub-types.
abstract final class FeedbackSubType {
  static const featureRequest = 'feature_request';
  static const bug = 'bug';
  static const subjectNotes = 'subject_notes';
  static const module = 'module';
  static const papers = 'papers';
  static const universityNotes = 'university_notes';
  static const newUniversity = 'new_university';
}

abstract final class FeedbackStatus {
  static const newStatus = 'new'; // `new` is a reserved word in Dart
  static const reviewed = 'reviewed';
  static const resolved = 'resolved';
  static const rejected = 'rejected';
}

/// Default currency for orders.
const kCurrencyInr = 'INR';
