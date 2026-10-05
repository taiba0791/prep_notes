import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/features/auth/domain/auth_failure.dart';

void main() {
  test('wrong email/password codes all map to one friendly message', () {
    for (final code in [
      'invalid-credential',
      'invalid-login-credentials',
      'wrong-password',
      'user-not-found', // don't reveal whether the email exists
    ]) {
      expect(AuthFailure.fromCode(code), AuthFailure.invalidCredential);
    }
  });

  test('common codes', () {
    expect(
      AuthFailure.fromCode('email-already-in-use'),
      AuthFailure.emailAlreadyInUse,
    );
    expect(AuthFailure.fromCode('weak-password'), AuthFailure.weakPassword);
    expect(AuthFailure.fromCode('network-request-failed'), AuthFailure.network);
    expect(AuthFailure.fromCode('popup-closed-by-user'), AuthFailure.cancelled);
  });

  test('unknown codes fall back safely', () {
    expect(AuthFailure.fromCode('something-new'), AuthFailure.unknown);
  });

  test('every failure has a non-empty message', () {
    for (final f in AuthFailure.values) {
      expect(f.message, isNotEmpty, reason: f.name);
    }
  });
}
