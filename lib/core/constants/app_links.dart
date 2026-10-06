import '../router/route_paths.dart';

/// Public web addresses of PrepNotes.
abstract final class AppLinks {
  /// The live website (Firebase Hosting). Phones send buyers here.
  static const website = 'https://prepnotes-635d6.web.app';

  /// A note's page on the website.
  static String noteOnWebsite(String noteId) =>
      '$website${RoutePaths.note(noteId)}';
}
