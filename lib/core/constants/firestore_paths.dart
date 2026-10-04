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

  // Sub-collections of users/{uid}
  static const entitlements = 'entitlements';
  static const recentlyViewed = 'recentlyViewed';
  static const studySessions = 'studySessions';
}

/// Full document / collection paths.
abstract final class FirestorePaths {
  static String user(String uid) => '${FirestoreCollections.users}/$uid';

  /// WRITTEN ONLY BY CLOUD FUNCTIONS.
  static String entitlements(String uid) =>
      '${user(uid)}/${FirestoreCollections.entitlements}';
  static String entitlement(String uid, String noteId) =>
      '${entitlements(uid)}/$noteId';

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

  /// Aggregate counters, maintained by Cloud Functions.
  static const statsGlobal = '${FirestoreCollections.stats}/global';
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
}

/// users/{uid}/entitlements/{noteId} — written ONLY by Cloud Functions.
abstract final class EntitlementFields {
  static const noteId = 'noteId';
  static const orderId = 'orderId';
  static const purchasedAt = 'purchasedAt';
  static const pricePaid = 'pricePaid'; // paise
}

/// users/{uid}/recentlyViewed/{noteId}
abstract final class RecentlyViewedFields {
  static const noteId = 'noteId';
  static const viewedAt = 'viewedAt';
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

  static const price = 'price'; // paise
  static const isFree = 'isFree';
  static const thumbnailUrl = 'thumbnailUrl';
  static const pageCount = 'pageCount';
  static const fileSizeBytes = 'fileSizeBytes';

  /// Private Storage path; clients can never read it directly.
  static const storagePath = 'storagePath';
  static const previewPages = 'previewPages';
  static const isPublished = 'isPublished';
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
  static const amount = 'amount'; // paise
  static const currency = 'currency';
  static const status = 'status'; // see OrderStatus
  static const razorpayOrderId = 'razorpayOrderId';
  static const razorpayPaymentId = 'razorpayPaymentId';
  static const createdAt = CommonFields.createdAt;
  static const paidAt = 'paidAt';
  static const failureReason = 'failureReason';
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

// ─────────────────────────── Stored values ────────────────────────────

abstract final class UserRole {
  static const student = 'student';
  static const admin = 'admin';
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
