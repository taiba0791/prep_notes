/// Firebase Storage folder layout. Must stay in sync with `storage.rules`.
abstract final class StoragePaths {
  /// PRIVATE — no client access. Served only via a short-lived signed URL
  /// from the `getNoteFileUrl` Cloud Function after an entitlement check.
  static String notePdf(String noteId) => 'notes_private/$noteId/file.pdf';

  // Public read, admin write
  static String noteThumbnail(String noteId) =>
      'notes_public/$noteId/thumbnail.jpg';
  static String notePreview(String noteId) =>
      'notes_public/$noteId/preview.pdf';

  /// A Resource Room upload (private to the student).
  static String roomFile(String uid, String itemId, String fileName) =>
      'room/$uid/$itemId/$fileName';

  /// Public read, admin write.
  static String universityLogo(String universityId) =>
      'universities/$universityId/logo';

  // Owner write, public read
  static String avatar(String uid) => 'avatars/$uid/avatar.jpg';
}
