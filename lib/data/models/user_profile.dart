import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import 'converters/timestamp_converter.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// A student's profile: the `users/{uid}` Firestore document.
///
/// JSON keys equal the [UserFields] constants (checked by a unit test).
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    /// The document id (= Firebase Auth uid). Not stored inside the document.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String uid,
    required String name,
    required String email,
    String? photoUrl,
    String? universityId,

    /// Semester number, 1–10. Null until the student picks one.
    int? semester,

    /// Mirror only — the real admin check is the `admin` custom claim.
    @Default(UserRole.student) String role,
    @Default(0) int totalStudyMinutes,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastLoginAt,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  /// Up to two letters for an avatar placeholder: "Taiba Shaikh" → "TS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
