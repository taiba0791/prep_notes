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

  // Auth errors (shown on login / register / password screens)
  static const authErrorInvalidCredential =
      'Email or password is incorrect. Please try again.';
  static const authErrorEmailInUse =
      'An account with this email already exists. Try logging in instead.';
  static const authErrorWeakPassword =
      'That password is too weak. Use at least 8 characters.';
  static const authErrorInvalidEmail = 'Please enter a valid email address.';
  static const authErrorUserDisabled =
      'This account has been disabled. Please contact support.';
  static const authErrorTooManyRequests =
      'Too many attempts. Please wait a few minutes and try again.';
  static const authErrorNetwork =
      'No internet connection. Check your network and try again.';
  static const authErrorRequiresRecentLogin =
      'For your security, please log in again and then retry.';
  static const authErrorAccountExists =
      'This email is already linked to another sign-in method. '
      'Log in with that method first.';
  static const authErrorProviderDisabled =
      'This sign-in method is not available right now.';
  static const authErrorCancelled = 'Sign-in was cancelled.';
  static const authErrorUnknown = 'Something went wrong. Please try again.';

  // Account
  static const signOut = 'Log out';

  // Form validation
  static const validationEmailRequired = 'Please enter your email.';
  static const validationEmailInvalid = 'Please enter a valid email address.';
  static const validationPasswordRequired = 'Please enter your password.';
  static const validationPasswordShort =
      'Password must be at least 8 characters.';
  static const validationPasswordWeak =
      'Use at least one letter and one number.';
  static const validationPasswordMismatch = "Passwords don't match.";
  static const validationNameRequired = 'Please enter your name.';
  static const validationNameShort = 'Name must be at least 2 characters.';
  static const validationNameLong = 'Name must be at most 60 characters.';

  // Auth screens — shared
  static const fieldEmail = 'Email';
  static const fieldPassword = 'Password';
  static const fieldNewPassword = 'Create a password';
  static const fieldConfirmPassword = 'Confirm password';
  static const fieldName = 'Full name';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const passwordHint =
      'At least 8 characters, with a letter and a number';

  // Login
  static const loginTitle = 'Welcome back';
  static const loginSubtitle = 'Log in to access your notes and purchases.';
  static const loginButton = 'Log in';
  static const forgotPasswordLink = 'Forgot password?';
  static const noAccountPrompt = "Don't have an account?";
  static const createAccountLink = 'Create one';

  // Register
  static const registerTitle = 'Create your account';
  static const registerSubtitle = 'Free to join. Buy only the notes you need.';
  static const registerButton = 'Create account';
  static const haveAccountPrompt = 'Already have an account?';
  static const loginLink = 'Log in';
  static const termsPrefix = 'By creating an account you agree to our ';
  static const termsLink = 'Terms';
  static const termsAnd = ' and ';
  static const privacyLink = 'Privacy Policy';

  // Forgot password
  static const forgotTitle = 'Reset your password';
  static const forgotSubtitle =
      "Enter your account email and we'll send you a reset link.";
  static const forgotButton = 'Send reset link';
  static const forgotSentTitle = 'Check your inbox';
  static const forgotSentMessage =
      "If an account exists for that email, we've sent a link to reset your "
      'password. It may take a minute — check your spam folder too.';
  static const backToLogin = 'Back to log in';
}
