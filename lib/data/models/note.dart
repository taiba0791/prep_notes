import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/timestamp_converter.dart';

part 'note.freezed.dart';
part 'note.g.dart';

/// A sellable set of notes: the `notes/{noteId}` document.
///
/// MONEY: [price] is in PAISE (₹149 = 14900).
/// [pageCount], [fileSizeBytes], [hasPreview] and [purchaseCount] are written
/// only by Cloud Functions (firestore.rules keeps them read-only for clients).
@freezed
abstract class Note with _$Note {
  const factory Note({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String title,
    @Default('') String description,
    required String universityId,
    required String semesterId,
    required String subjectId,
    required String moduleId,

    // Denormalized for list screens ("Mumbai University · Sem 3").
    @Default('') String universityName,
    @Default(0) int semesterNumber,
    @Default('') String subjectName,
    @Default('') String moduleTitle,

    @Default(0) int price,
    @Default(false) bool isFree,
    String? thumbnailUrl,
    @Default(0) int pageCount,
    @Default(0) int fileSizeBytes,

    /// Private Storage path of the PDF (null until uploaded).
    String? storagePath,

    /// How many pages the free preview shows (0 = no preview).
    @Default(3) int previewPages,
    @Default(false) bool hasPreview,
    @Default(false) bool isPublished,
    @Default(0) int purchaseCount,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> searchKeywords,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _Note;

  const Note._();

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  bool get hasPdf => storagePath != null && storagePath!.isNotEmpty;
}
