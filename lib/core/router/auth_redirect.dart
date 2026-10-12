import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

const Set<String> _publicPaths = {RoutePaths.login, RoutePaths.register};

/// Paths that never resume after the splash.
const Set<String> _entryPaths = {
  RoutePaths.splash,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.suspended,
};

/// Owner-only actions under `/products/:productId/`.
const Set<String> _ownerOnlyActions = {'adjust', 'count'};
const String _productsSegment = 'products';
const int _productActionSegments = 3;

/// The redirect table of design §3.2. Returns the location to go to, or
/// `null` to stay.
String? authRedirect(AuthState auth, Uri location) {
  final path = location.path;
  switch (auth) {
    case AuthUnknown():
      if (path == RoutePaths.splash) {
        return null;
      }
      return Uri(
        path: RoutePaths.splash,
        queryParameters: {RoutePaths.fromParameter: location.toString()},
      ).toString();
    case AuthSignedOut():
      return _publicPaths.contains(path) ? null : RoutePaths.login;
    case AuthSuspended():
      return path == RoutePaths.suspended ? null : RoutePaths.suspended;
    case AuthSignedIn(:final session):
      if (_publicPaths.contains(path) || path == RoutePaths.suspended) {
        return RoutePaths.home;
      }
      if (session.shop.role == ShopRole.staff) {
        return _ownerOnlyFallback(location);
      }
      return null;
  }
}

/// Where the splash goes once the user is signed in: the `from` location
/// when it is an authenticated route, else home.
String splashDestination(Uri splashLocation) {
  final from = splashLocation.queryParameters[RoutePaths.fromParameter];
  final target = from == null ? null : Uri.tryParse(from);
  if (target == null ||
      target.hasScheme ||
      target.hasAuthority ||
      !target.path.startsWith('/') ||
      _entryPaths.contains(target.path)) {
    return RoutePaths.home;
  }
  return from!;
}

/// Staff opening an owner-only product action go to the product instead.
String? _ownerOnlyFallback(Uri location) {
  final segments = location.pathSegments;
  final isOwnerOnly =
      segments.length == _productActionSegments &&
      segments.first == _productsSegment &&
      _ownerOnlyActions.contains(segments.last);
  return isOwnerOnly ? RoutePaths.productDetailOf(segments[1]) : null;
}
