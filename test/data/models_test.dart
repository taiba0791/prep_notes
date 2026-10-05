import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/data/models/university.dart';
import 'package:prepnotes/data/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    final created = DateTime.utc(2026, 10, 5, 10, 30);

    test('reads a Firestore document (Timestamp → DateTime)', () {
      final p = UserProfile.fromJson({
        UserFields.name: 'Taiba Shaikh',
        UserFields.email: 'taiba@example.com',
        UserFields.semester: 3,
        UserFields.createdAt: Timestamp.fromDate(created),
      }).copyWith(uid: 'u1');

      expect(p.uid, 'u1');
      expect(p.name, 'Taiba Shaikh');
      expect(p.semester, 3);
      // Firestore returns local time; compare the moment, not the time zone.
      expect(p.createdAt!.isAtSameMomentAs(created), isTrue);
      // Defaults for missing fields
      expect(p.role, UserRole.student);
      expect(p.totalStudyMinutes, 0);
      expect(p.photoUrl, isNull);
    });

    test('writes only data-model fields, with Firestore Timestamps', () {
      final json = UserProfile(
        uid: 'u1',
        name: 'A',
        email: 'a@b.com',
        createdAt: created,
      ).toJson();

      expect(json.containsKey('uid'), isFalse, reason: 'uid is the doc id');
      expect(json[UserFields.createdAt], Timestamp.fromDate(created));
      expect(
        json.containsKey(UserFields.photoUrl),
        isFalse,
        reason: 'nulls are not written (build.yaml include_if_null)',
      );
    });

    test('JSON keys are exactly the UserFields constants', () {
      final json = UserProfile(
        name: 'A',
        email: 'a@b.com',
        photoUrl: 'p',
        universityId: 'u',
        semester: 1,
        createdAt: created,
        lastLoginAt: created,
      ).toJson();
      expect(json.keys.toSet(), {
        UserFields.name,
        UserFields.email,
        UserFields.photoUrl,
        UserFields.universityId,
        UserFields.semester,
        UserFields.role,
        UserFields.totalStudyMinutes,
        UserFields.createdAt,
        UserFields.lastLoginAt,
      });
    });

    test('initials', () {
      UserProfile p(String name) => UserProfile(name: name, email: 'e');
      expect(p('Taiba Shaikh').initials, 'TS');
      expect(p('  priya  ').initials, 'P');
      expect(p('a b c').initials, 'AB');
      expect(p('').initials, '?');
    });
  });

  group('University', () {
    test('reads a document with defaults', () {
      final u = University.fromJson({
        UniversityFields.name: 'University of Mumbai',
      }).copyWith(id: 'mu');
      expect(u.id, 'mu');
      expect(u.shortName, '');
      expect(u.isActive, isTrue);
      expect(u.order, 0);
    });

    test('JSON keys are UniversityFields constants', () {
      final json = const University(
        name: 'N',
        shortName: 'S',
        city: 'C',
        logoUrl: 'L',
        description: 'D',
      ).toJson();
      expect(json.keys.toSet(), {
        UniversityFields.name,
        UniversityFields.shortName,
        UniversityFields.city,
        UniversityFields.logoUrl,
        UniversityFields.description,
        UniversityFields.isActive,
        UniversityFields.order,
      });
    });
  });
}
