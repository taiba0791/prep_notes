import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/features/auth/domain/validators.dart';

void main() {
  group('email', () {
    test('valid', () {
      expect(Validators.email('taiba@gmail.com'), isNull);
      expect(Validators.email('  a.b+c@college.ac.in '), isNull);
    });
    test('invalid', () {
      expect(Validators.email(''), AppStrings.validationEmailRequired);
      expect(Validators.email(null), AppStrings.validationEmailRequired);
      for (final bad in ['taiba', 'taiba@', '@gmail.com', 'a@b', 'a b@c.com']) {
        expect(
          Validators.email(bad),
          AppStrings.validationEmailInvalid,
          reason: bad,
        );
      }
    });
  });

  group('newPassword', () {
    test('valid', () => expect(Validators.newPassword('notes2026'), isNull));
    test('too short', () {
      expect(Validators.newPassword('ab1'), AppStrings.validationPasswordShort);
    });
    test('needs a letter and a number', () {
      expect(
        Validators.newPassword('12345678'),
        AppStrings.validationPasswordWeak,
      );
      expect(
        Validators.newPassword('abcdefgh'),
        AppStrings.validationPasswordWeak,
      );
    });
  });

  test('passwordRequired only checks non-empty (old passwords allowed)', () {
    expect(Validators.passwordRequired('x'), isNull);
    expect(
      Validators.passwordRequired(''),
      AppStrings.validationPasswordRequired,
    );
  });

  test('confirmPassword', () {
    final check = Validators.confirmPassword('notes2026');
    expect(check('notes2026'), isNull);
    expect(check('notes2027'), AppStrings.validationPasswordMismatch);
  });

  group('name (matches firestore.rules: 2–60 chars)', () {
    test('valid', () => expect(Validators.name(' Taiba '), isNull));
    test('invalid', () {
      expect(Validators.name(''), AppStrings.validationNameRequired);
      expect(Validators.name('A'), AppStrings.validationNameShort);
      expect(Validators.name('x' * 61), AppStrings.validationNameLong);
    });
  });
}
