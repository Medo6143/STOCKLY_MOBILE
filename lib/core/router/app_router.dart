import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/auth_redirect.dart';
import 'package:stockly/core/router/home_shell.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/router/router_refresh.dart';
import 'package:stockly/core/widgets/not_found_screen.dart';
import 'package:stockly/core/widgets/placeholder_screen.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/login_screen.dart';
import 'package:stockly/features/auth/presentation/screens/register_screen.dart';
import 'package:stockly/features/auth/presentation/screens/shop_suspended_screen.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_state.dart';
import 'package:stockly/features/splash/presentation/screens/splash_screen.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Every route of design §3.1. Screens that later briefs build show a
/// [PlaceholderScreen]. Sprint 3 has three tabs (products, invoices,
/// settings); dashboard and sales join the shell in Sprint 4.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);
  final routes = _RouteTable(GlobalKey<NavigatorState>());
  final router = GoRouter(
    navigatorKey: routes.rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ref.read(authProvider).value ?? const AuthState.unknown(),
      state.uri,
      splashFinished: ref.read(splashProvider).finished,
    ),
    errorBuilder: (context, state) =>
        NotFoundScreen(onGoHome: () => context.go(RoutePaths.home)),
    routes: routes.all,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// [path] relative to its [parent] route.
String _child(String path, String parent) => path.substring(parent.length + 1);

Widget _placeholder(BuildContext context, GoRouterState state) =>
    const PlaceholderScreen();

/// The route tree. Full-screen flows (capture, review, quick sale) use the
/// root navigator so the tab bar is hidden.
final class _RouteTable {
  new(this.rootNavigatorKey);

  final GlobalKey<NavigatorState> rootNavigatorKey;

  GoRoute _route(
    String path,
    String name, {
    String? parent,
    bool fullScreen = false,
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: parent == null ? path : _child(path, parent),
    name: name,
    parentNavigatorKey: fullScreen ? rootNavigatorKey : null,
    builder: _placeholder,
    routes: routes,
  );

  List<RouteBase> get all => [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RoutePaths.register,
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: RoutePaths.suspended,
      name: RouteNames.suspended,
      builder: (context, state) => const ShopSuspendedScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [_productsRoute]),
        StatefulShellBranch(routes: [_invoicesRoute]),
        StatefulShellBranch(routes: [_settingsRoute]),
      ],
    ),
    _route(
      RoutePaths.dashboard,
      RouteNames.dashboard,
      routes: [
        _route(
          RoutePaths.expiringSoon,
          RouteNames.expiringSoon,
          parent: RoutePaths.dashboard,
        ),
      ],
    ),
    _route(
      RoutePaths.sales,
      RouteNames.sales,
      routes: [
        _route(
          RoutePaths.quickSale,
          RouteNames.quickSale,
          parent: RoutePaths.sales,
          fullScreen: true,
        ),
        _route(
          RoutePaths.saleDetail,
          RouteNames.saleDetail,
          parent: RoutePaths.sales,
        ),
      ],
    ),
  ];

  GoRoute get _productsRoute => GoRoute(
    path: RoutePaths.products,
    name: RouteNames.products,
    builder: (context, state) =>
        PlaceholderScreen(title: AppLocalizations.of(context).navProducts),
    routes: [
      _route(
        RoutePaths.productCreate,
        RouteNames.productCreate,
        parent: RoutePaths.products,
      ),
      _route(
        RoutePaths.productDetail,
        RouteNames.productDetail,
        parent: RoutePaths.products,
        routes: [
          for (final (path, name) in const [
            (RoutePaths.productEdit, RouteNames.productEdit),
            (RoutePaths.unitCreate, RouteNames.unitCreate),
            (RoutePaths.unitEdit, RouteNames.unitEdit),
            (RoutePaths.stockAdjust, RouteNames.stockAdjust),
            (RoutePaths.stockCount, RouteNames.stockCount),
            (RoutePaths.movements, RouteNames.movements),
          ])
            _route(path, name, parent: RoutePaths.productDetail),
        ],
      ),
    ],
  );

  GoRoute get _invoicesRoute => GoRoute(
    path: RoutePaths.invoices,
    name: RouteNames.invoices,
    builder: (context, state) =>
        PlaceholderScreen(title: AppLocalizations.of(context).navInvoices),
    routes: [
      _route(
        RoutePaths.scanCapture,
        RouteNames.scanCapture,
        parent: RoutePaths.invoices,
        fullScreen: true,
      ),
      _route(
        RoutePaths.scanQueue,
        RouteNames.scanQueue,
        parent: RoutePaths.invoices,
      ),
      _route(
        RoutePaths.invoiceDetail,
        RouteNames.invoiceDetail,
        parent: RoutePaths.invoices,
        routes: [
          _route(
            RoutePaths.invoiceReview,
            RouteNames.invoiceReview,
            parent: RoutePaths.invoiceDetail,
            fullScreen: true,
            routes: [
              _route(
                RoutePaths.invoiceLineEdit,
                RouteNames.invoiceLineEdit,
                parent: RoutePaths.invoiceReview,
                fullScreen: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  GoRoute get _settingsRoute => GoRoute(
    path: RoutePaths.settings,
    name: RouteNames.settings,
    builder: (context, state) => const SettingsScreen(),
  );
}
