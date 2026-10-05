import 'package:freezed_annotation/freezed_annotation.dart';

part 'university.freezed.dart';
part 'university.g.dart';

/// A university: the `universities/{universityId}` Firestore document.
///
/// Phase 1 only reads these (profile dropdown); Phase 2 adds admin CRUD.
/// JSON keys equal the [UniversityFields] constants (checked by a unit test).
@freezed
abstract class University with _$University {
  const factory University({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String name,
    @Default('') String shortName,
    String? city,
    String? logoUrl,
    String? description,
    @Default(true) bool isActive,

    /// Manual sort position (lower first).
    @Default(0) int order,
  }) = _University;

  factory University.fromJson(Map<String, dynamic> json) =>
      _$UniversityFromJson(json);
}
