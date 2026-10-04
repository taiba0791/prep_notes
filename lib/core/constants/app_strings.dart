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
  static const toggleDarkMode = 'Toggle dark mode';
}
