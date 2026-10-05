import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/router/route_guards.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

String? redirect(AuthSession session, String location) =>
    guardRedirect(session: session, uri: Uri.parse(location));

void main() {
  group('guest', () {
    const s = AuthSession.guest;

    test('can open public pages', () {
      for (final path in [
        RoutePaths.home,
        RoutePaths.notes,
        RoutePaths.university('mu'),
        RoutePaths.note('n1'),
        RoutePaths.studyZone,
        RoutePaths.studentVoice,
        RoutePaths.resources,
        RoutePaths.login,
      ]) {
        expect(redirect(s, path), isNull, reason: path);
      }
    });

    test('is sent to login (remembering the page) for protected pages', () {
      expect(redirect(s, RoutePaths.profile), '/login?from=%2Fprofile');
      expect(redirect(s, RoutePaths.purchases), '/login?from=%2Fpurchases');
      expect(
        redirect(s, RoutePaths.noteViewer('n1')),
        '/login?from=%2Fnotes%2Fn1%2Fview',
      );
      expect(
        redirect(s, RoutePaths.checkout('n1')),
        '/login?from=%2Fcheckout%2Fn1',
      );
      expect(
        redirect(s, RoutePaths.adminOrders),
        '/login?from=%2Fadmin%2Forders',
      );
    });
  });

  group('student', () {
    const s = AuthSession(uid: 'student1');

    test('can open protected pages', () {
      expect(redirect(s, RoutePaths.profile), isNull);
      expect(redirect(s, RoutePaths.noteViewer('n1')), isNull);
    });

    test('cannot open admin pages', () {
      expect(redirect(s, RoutePaths.admin), RoutePaths.home);
      expect(redirect(s, RoutePaths.adminUser('u1')), RoutePaths.home);
    });

    test('is sent back to the remembered page after login', () {
      expect(redirect(s, '/login?from=%2Fprofile'), RoutePaths.profile);
      expect(redirect(s, RoutePaths.login), RoutePaths.home);
    });

    test('never follows an external "from" link', () {
      expect(
        redirect(s, '/login?from=https%3A%2F%2Fevil.com'),
        RoutePaths.home,
      );
      expect(redirect(s, '/login?from=%2F%2Fevil.com'), RoutePaths.home);
      expect(redirect(s, '/login?from=%2F%5Cevil.com'), RoutePaths.home);
    });
  });

  test('admin can open admin pages', () {
    expect(
      redirect(
        const AuthSession(uid: 'admin1', isAdmin: true),
        RoutePaths.adminNotes,
      ),
      isNull,
    );
    expect(
      redirect(
        const AuthSession(uid: 'admin1', isAdmin: true),
        RoutePaths.adminOrder('o1'),
      ),
      isNull,
    );
  });

  test('while the session is loading, nothing is redirected', () {
    for (final path in [
      RoutePaths.profile,
      RoutePaths.admin,
      RoutePaths.login,
    ]) {
      expect(redirect(AuthSession.loading, path), isNull, reason: path);
    }
  });

  test('"/administrator" is not treated as an admin page', () {
    expect(requiresAdmin('/administrator'), isFalse);
  });
}
