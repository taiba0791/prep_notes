import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/timestamp_converter.dart';
import 'note.dart';

part 'recently_viewed.freezed.dart';
part 'recently_viewed.g.dart';

/// `users/{uid}/recentlyViewed/{noteId}` — a small copy of a note the user
/// opened, so "Recently viewed" needs no extra reads. Capped at 20 per user.
@freezed
abstract class RecentlyViewed with _$RecentlyViewed {
  const factory RecentlyViewed({
    required String noteId,
    required String title,
    @Default('') String universityName,
    @Default(0) int semesterNumber,
    @Default('') String subjectName,
    @Default(0) int price,
    @Default(false) bool isFree,
    String? thumbnailUrl,
    @Default(0) int pageCount,
    @TimestampConverter() DateTime? viewedAt,
  }) = _RecentlyViewed;

  const RecentlyViewed._();

  factory RecentlyViewed.fromJson(Map<String, dynamic> json) =>
      _$RecentlyViewedFromJson(json);

  factory RecentlyViewed.fromNote(Note n) => RecentlyViewed(
    noteId: n.id,
    title: n.title,
    universityName: n.universityName,
    semesterNumber: n.semesterNumber,
    subjectName: n.subjectName,
    price: n.price,
    isFree: n.isFree,
    thumbnailUrl: n.thumbnailUrl,
    pageCount: n.pageCount,
  );

  /// Enough of a [Note] to draw a note card.
  Note toNote() => Note(
    id: noteId,
    title: title,
    universityId: '',
    semesterId: '',
    subjectId: '',
    moduleId: '',
    universityName: universityName,
    semesterNumber: semesterNumber,
    subjectName: subjectName,
    price: price,
    isFree: isFree,
    thumbnailUrl: thumbnailUrl,
    pageCount: pageCount,
    isPublished: true,
  );
}
