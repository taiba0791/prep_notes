import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import 'user_profile.dart';

part 'admin_stats.freezed.dart';
part 'admin_stats.g.dart';

/// `stats/global` — totals kept by Cloud Functions (admin read only).
@freezed
abstract class GlobalStats with _$GlobalStats {
  const factory GlobalStats({
    @Default(0) int totalStudents,
    @Default(0) int totalNotes, // published
    @Default(0) int totalPurchases,
    @Default(0) int totalRevenue, // paise
  }) = _GlobalStats;

  factory GlobalStats.fromJson(Map<String, dynamic> json) =>
      _$GlobalStatsFromJson(json);
}

/// `stats_daily/{yyyy-MM-dd}` — one day's sales (India time).
@freezed
abstract class DailyStat with _$DailyStat {
  const factory DailyStat({
    required String date,
    @Default(0) int purchases,
    @Default(0) int revenue, // paise
    @Default(0) int refunds,
  }) = _DailyStat;

  factory DailyStat.fromJson(Map<String, dynamic> json) =>
      _$DailyStatFromJson(json);
}

/// A student as the admin sees them: the profile plus server-only flags.
/// (Kept apart from [UserProfile] so the app's own profile writes never
/// include server fields.)
class AdminUser {
  const AdminUser({required this.profile, this.disabled = false});

  final UserProfile profile;
  final bool disabled;

  String get uid => profile.uid;
  bool get isAdmin => profile.role == UserRole.admin;
}
