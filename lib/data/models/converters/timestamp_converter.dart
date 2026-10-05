import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converts Firestore [Timestamp] ⇄ Dart [DateTime] for freezed models.
/// Use on nullable `DateTime?` fields: `@TimestampConverter() DateTime? x`.
class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) => switch (json) {
    Timestamp() => json.toDate(),
    DateTime() => json,
    // Defensive: tolerate ISO strings / epoch millis from scripts or tests.
    String() => DateTime.tryParse(json),
    int() => DateTime.fromMillisecondsSinceEpoch(json),
    _ => null,
  };

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
