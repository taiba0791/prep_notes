/// Every URL in the app. Use these instead of typing paths by hand:
/// `context.go(RoutePaths.university(id))`.
abstract final class RoutePaths {
  // Public pages
  static const home = '/';
  static const search = '/search';
  static const queryParam = 'q';
  static String searchFor(String text) => text.isEmpty
      ? search
      : Uri(path: search, queryParameters: {queryParam: text}).toString();
  static const about = '/about';
  static const contact = '/contact';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const refundPolicy = '/refund-policy';
  static const deliveryPolicy = '/delivery-policy';

  // Auth
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// Query parameter that remembers where to go back to after login.
  static const fromParam = 'from';

  /// Adds `?from=...` to an auth page so the "go back to" target survives
  /// switching between Login, Register and Forgot password.
  static String withFrom(String path, String? from) =>
      (from == null || from.isEmpty)
      ? path
      : Uri(path: path, queryParameters: {fromParam: from}).toString();

  // Notes: University → Semester → Subject → Note
  static const notes = '/notes';
  static String university(String universityId) => '/notes/u/$universityId';
  static String semester(String semesterId) => '/notes/s/$semesterId';
  static String subject(String subjectId) => '/notes/sub/$subjectId';
  static String note(String noteId) => '/notes/$noteId';
  static String noteViewer(String noteId) => '/notes/$noteId/view';

  /// Free preview (first pages) — public.
  static String notePreview(String noteId) => '/notes/$noteId/preview';

  // Purchases & checkout
  static const purchases = '/purchases';
  static String checkout(String noteId) => '/checkout/$noteId';
  static String checkoutBundle(String semesterId) =>
      '/checkout/bundle/$semesterId';
  static String checkoutRoom(String planKey) => '/checkout/room/$planKey';

  /// One saved item in the Resource Room (full screen).
  static String roomItem(String itemId) => '/resources/item/$itemId';

  // Other main sections
  static const studyZone = '/study-zone';
  static const studentVoice = '/student-voice';
  static const resources = '/resources';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const profileChangePassword = '/profile/change-password';

  // Admin panel
  static const admin = '/admin';
  static const adminUniversities = '/admin/universities';
  static const adminSemesters = '/admin/semesters';
  static const adminSubjects = '/admin/subjects';
  static const adminModules = '/admin/modules';
  static const adminNotes = '/admin/notes';
  static const adminNoteNew = '/admin/notes/new';
  static String adminNoteEdit(String noteId) => '/admin/notes/$noteId/edit';
  static const adminUsers = '/admin/users';
  static String adminUser(String uid) => '/admin/users/$uid';
  static const adminOrders = '/admin/orders';
  static String adminOrder(String orderId) => '/admin/orders/$orderId';
  static const adminRoomPlans = '/admin/room-plans';
  static const adminStudentVoice = '/admin/student-voice';
}
