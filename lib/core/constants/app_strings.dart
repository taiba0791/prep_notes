/// Every user-facing string lives here so the app can be translated later
/// (e.g. by moving these into Flutter's ARB/gen-l10n files).
abstract final class AppStrings {
  static const appName = 'PrepNotes';
  static const appTagline = 'Notes, resources and focus tools for students';

  // Main navigation
  static const navHome = 'Home';
  static const navNotes = 'Notes';
  static const navStudyZone = 'Study Zone';
  static const navResources = 'Resources';
  static const navProfile = 'Profile';

  // Common
  static const comingSoon = 'Coming soon';
  static const goHome = 'Go to Home';
  static const emulatorBanner = 'EMULATOR';

  // 404
  static const notFoundTitle = 'Page not found';
  static const notFoundMessage =
      "The page you're looking for doesn't exist or has moved.";

  // Page titles (placeholders until each phase builds the real screen)
  static const pageSearch = 'Search';
  static const pageAbout = 'About';
  static const pageContact = 'Contact';
  static const pagePrivacy = 'Privacy Policy';
  static const pageTerms = 'Terms of Service';
  static const pageRefundPolicy = 'Refund Policy';
  static const pageLogin = 'Log in';
  static const pageRegister = 'Create account';
  static const pageForgotPassword = 'Forgot password';
  static const pageUniversity = 'University';
  static const pageSemester = 'Semester';
  static const pageSubject = 'Subject';
  static const pageNoteDetails = 'Note details';
  static const pageNoteViewer = 'Note viewer';
  static const pagePurchases = 'My Purchases';
  static const pageCheckout = 'Checkout';
  static const pageStudentVoice = 'Student Voice';
  static const pageAdminDashboard = 'Admin · Dashboard';
  static const pageAdminUniversities = 'Admin · Universities';
  static const pageAdminSemesters = 'Admin · Semesters';
  static const pageAdminSubjects = 'Admin · Subjects';
  static const pageAdminModules = 'Admin · Modules';
  static const pageAdminNotes = 'Admin · Notes';
  static const pageAdminNoteNew = 'Admin · New note';
  static const pageAdminNoteEdit = 'Admin · Edit note';
  static const pageAdminUsers = 'Admin · Users';
  static const pageAdminUser = 'Admin · User details';
  static const pageAdminOrders = 'Admin · Orders';
  static const pageAdminOrder = 'Admin · Order details';
  static const pageAdminResources = 'Admin · Resources';
  static const pageAdminStudentVoice = 'Admin · Student Voice';

  // DEBUG-only sign-in shortcuts (removed in Phase 1)
  static const debugSignInStudent = 'Continue as student (debug)';
  static const debugSignInAdmin = 'Continue as admin (debug)';
  static const debugSignOut = 'Sign out (debug)';
}
