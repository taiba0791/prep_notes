import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog.freezed.dart';
part 'catalog.g.dart';

// Catalog hierarchy: University → Semester → Subject → Module → Note.
// JSON keys equal the *Fields constants in firestore_paths.dart (checked by
// tests). `id` is the document id and is never stored inside the document.

/// `semesters/{semesterId}`
@freezed
abstract class Semester with _$Semester {
  const factory Semester({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String universityId,
    required int number,
    required String name,
    @Default(true) bool isActive,
  }) = _Semester;

  factory Semester.fromJson(Map<String, dynamic> json) =>
      _$SemesterFromJson(json);
}

/// `subjects/{subjectId}`
@freezed
abstract class Subject with _$Subject {
  const factory Subject({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String universityId,
    required String semesterId,
    required String name,
    @Default('') String code,
    @Default('') String description,
    @Default(true) bool isActive,
  }) = _Subject;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);
}

/// `modules/{moduleId}`
@freezed
abstract class Module with _$Module {
  const factory Module({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String subjectId,
    required int number,
    required String title,
    @Default(true) bool isActive,
  }) = _Module;

  factory Module.fromJson(Map<String, dynamic> json) => _$ModuleFromJson(json);
}
