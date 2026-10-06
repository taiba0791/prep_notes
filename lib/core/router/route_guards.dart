import '../../features/auth/domain/auth_session.dart';
import 'route_paths.dart';

/// Pages that need a signed-in user.
bool requiresSignIn(String path) {
  if (requiresAdmin(path)) return true;
  if (path == RoutePaths.profile || path.startsWith('${RoutePaths.profile}/')) {
    return true;
  }
  if (path == RoutePaths.purchases) return true;
  if (path.startsWith('/checkout/')) return true;
  // A saved Resource Room item belongs to a signed-in student.
  if (path.startsWith('${RoutePaths.resources}/item/')) return true;
  // The PDF viewer (/notes/:noteId/view) needs a signed-in buyer.
  final segments = Uri.parse(path).pathSegments;
  return segments.length == 3 &&
      segments.first == 'notes' &&
      segments.last == 'view';
}

/// Pages that need the `admin` custom claim.
bool requiresAdmin(String path) =>
    path == RoutePaths.admin || path.startsWith('${RoutePaths.admin}/');

/// Login / register / forgot-password: pointless once signed in.
bool isAuthPage(String path) =>
    path == RoutePaths.login ||
    path == RoutePaths.register ||
    path == RoutePaths.forgotPassword;

/// Decides where to send the user before a page is shown.
/// Returns `null` to allow the page, or a new location to redirect to.
///
/// Note: hiding pages is only for user experience. Real protection is in
/// Firestore/Storage rules and Cloud Functions.
String? guardRedirect({required AuthSession session, required Uri uri}) {
  final path = uri.path;

  // Firebase is still restoring the login (e.g. after a page refresh):
  // don't decide yet. The router re-runs this as soon as it knows.
  if (session.isLoading) return null;

  if (!session.isSignedIn && requiresSignIn(path)) {
    final from = Uri.encodeComponent(uri.toString());
    return '${RoutePaths.login}?${RoutePaths.fromParam}=$from';
  }

  if (session.isSignedIn && !session.isAdmin && requiresAdmin(path)) {
    return RoutePaths.home;
  }

  if (session.isSignedIn && isAuthPage(path)) {
    final from = uri.queryParameters[RoutePaths.fromParam];
    // Only allow in-app paths, never an external URL.
    final isSafe =
        from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith(r'/\');
    return isSafe ? from : RoutePaths.home;
  }

  return null;
}
