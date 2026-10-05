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
  static const navResourceRoom = 'Resource Room';
  static const navStudentVoice = 'Student Voice';
  static const signUpFree = 'Sign up free';

  // Common
  static const comingSoon = 'Coming soon';
  static const goHome = 'Go to Home';
  static const emulatorBanner = 'EMULATOR';
  static const switchToDark = 'Switch to dark mode';
  static const switchToLight = 'Switch to light mode';

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

  // Common states
  static const errorTitle = "Couldn't load this";
  static const errorMessage =
      'Please check your internet connection and try again.';
  static const retry = 'Try again';
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const notSet = 'Not set';

  // Profile
  static const profileSettingUpTitle = 'Setting up your profile…';
  static const profileSettingUpMessage =
      'This only takes a moment after you sign up.';
  static const adminBadge = 'Admin';
  static const verifyEmailTitle = 'Please verify your email';
  static const verifyEmailMessage =
      "We sent a link to your inbox. You'll need it before buying notes.";
  static const verifyEmailResend = 'Resend email';
  static const verifyEmailDone = "I've verified";
  static const verifyEmailSent = 'Verification email sent.';
  static const editProfile = 'Edit profile';
  static const fieldUniversity = 'University';
  static const fieldSemester = 'Semester';
  static String semesterLabel(int n) => 'Semester $n';
  static const statPurchases = 'Purchases';
  static const statStudyTime = 'Study time';
  static const statRecentlyViewed = 'Recently viewed';
  static String studyMinutes(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';
  static const linkMyPurchases = 'My purchases';
  static const linkAdminPanel = 'Admin panel';
  static const signOutConfirmTitle = 'Log out?';
  static const signOutConfirmMessage =
      "You'll need to log in again to see your purchases.";
  static const universitiesUnavailable =
      "Couldn't load universities. You can set it later.";
  static const noUniversitiesYet =
      'Universities will appear here soon. You can set it later.';
  static const profileSaved = 'Profile saved.';

  // ── Admin ──────────────────────────────────────────────
  static const adminTitle = 'Admin';
  static const adminBackToSite = 'Back to site';
  static const adminDashboard = 'Dashboard';
  static const adminUniversities = 'Universities';
  static const adminSemesters = 'Semesters';
  static const adminSubjects = 'Subjects';
  static const adminModules = 'Modules';
  static const adminNotes = 'Notes';
  static const adminUsers = 'Users';
  static const adminOrders = 'Orders';
  static const adminResources = 'Resources';
  static const adminStudentVoice = 'Student Voice';
  static const adminDashboardSoon =
      'Live numbers and charts arrive in Phase 5.';
  static const adminStatStudents = 'Students';
  static const adminStatNotes = 'Notes';
  static const adminStatPurchases = 'Purchases';
  static const adminStatRevenue = 'Revenue';

  static const add = 'Add';
  static const edit = 'Edit';
  static const delete = 'Delete';
  static const active = 'Active';
  static const inactive = 'Inactive';
  static const searchHint = 'Search';
  static const loadMore = 'Load more';
  static const actions = 'Actions';
  static const required = 'Required';
  static const saved = 'Saved.';
  static const deleted = 'Deleted.';
  static String deleteConfirmTitle(String what) => 'Delete "$what"?';
  static const deleteConfirmMessage = 'This cannot be undone.';
  static String inUse(String children) =>
      "Can't delete: it still has $children. Delete or move those first.";

  static const pickUniversity = 'Choose a university';
  static const pickSemester = 'Choose a semester';
  static const pickSubject = 'Choose a subject';
  static const pickModule = 'Choose a module';
  static const anyOption = 'All';
  static const nothingHereYet = 'Nothing here yet';
  static const addFirstItem = 'Use “Add” to create the first one.';
  static const chooseParentFirst = 'Choose the filters above to see items.';

  static const fieldShortName = 'Short name (e.g. MU)';
  static const fieldCity = 'City';
  static const fieldDescription = 'Description';
  static const fieldOrder = 'Sort order';
  static const fieldNumber = 'Number';
  static const fieldTitle = 'Title';
  static const fieldCode = 'Code (optional)';
  static const fieldLogo = 'Logo';
  static const chooseImage = 'Choose image';
  static const imageTooLarge = 'Image is too large.';
  static const mustBeNumber = 'Enter a whole number.';

  // Admin · notes
  static const newNote = 'New note';
  static const editNote = 'Edit note';
  static const fieldPrice = 'Price (₹)';
  static const fieldFree = 'Free note';
  static const fieldTags = 'Tags (comma separated)';
  static const fieldPreviewPages = 'Free preview pages';
  static const fieldPublished = 'Published (visible to students)';
  static const publishNeedsPdf = 'Upload the PDF before publishing.';
  static const fieldThumbnail = 'Thumbnail';
  static const fieldPdf = 'Notes PDF';
  static const choosePdf = 'Choose PDF';
  static const replacePdf = 'Replace PDF';
  static const pdfAttached = 'PDF attached';
  static const pdfTooLarge = 'PDF is too large (max 50 MB).';
  static const invalidPrice = 'Enter a price like 149 or 149.50.';
  static const priceMustBePositive = 'A paid note needs a price above ₹0.';
  static const uploading = 'Uploading…';
  static const draft = 'Draft';
  static const published = 'Published';
  static const free = 'Free';
  static String pages(int n) => '$n pages';
  static String noteContext(String uni, int sem, String subject) =>
      '$uni · Sem $sem · $subject';
  static const noteSaveFailed =
      "Couldn't save the note. Your draft is kept — try again.";

  // Profile photo
  static const changePhoto = 'Change profile photo';
  static const photoFromGallery = 'Choose from gallery';
  static const photoFromCamera = 'Take a photo';
  static const photoRemove = 'Remove photo';
  static const photoUpdated = 'Profile photo updated.';
  static const photoRemoved = 'Profile photo removed.';
  static const photoTooLarge = 'That photo is too large. Please pick another.';
  static const photoFailed = "Couldn't update your photo. Please try again.";

  // Change password
  static const changePassword = 'Change password';
  static const fieldCurrentPassword = 'Current password';
  static const fieldNewPasswordShort = 'New password';
  static const passwordChanged = 'Password changed.';

  // Delete account
  static const deleteAccount = 'Delete account';
  static const deleteAccountTitle = 'Delete your account?';
  static const deleteAccountMessage =
      'This permanently deletes your profile, photo, purchases access and '
      'study history. It cannot be undone.\n\n'
      'Order records are kept (without personal details) for accounting.';
  static const deleteAccountPasswordHint = 'Enter your password to confirm.';
  static const deleteAccountGoogleHint =
      "You'll be asked to sign in with Google again to confirm.";
  static const deleteAccountConfirm = 'Delete permanently';
  static const accountDeleted = 'Your account has been deleted.';

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

  // Auth screens — claret welcome panel
  static const authPanelHeadlineStart = 'Pick up where ';
  static const authPanelHeadlineAccent = 'your last revision';
  static const authPanelHeadlineEnd = ' ended.';
  static const authPanelTagline =
      'Your purchases, study time and requests stay with your account.';

  // Login
  static const loginTitle = 'Log in';
  static const loginSubtitle = 'Log in to access your notes and purchases.';
  static const loginButton = 'Log in';
  static const continueWithGoogle = 'Continue with Google';
  static const orDivider = 'or use email';
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
