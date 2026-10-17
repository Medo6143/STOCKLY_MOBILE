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
import 'package:stockly/features/invoices/presentation/providers/invoice_route_query.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_detail_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_line_editor_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_list_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_review_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_capture_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_queue_screen.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/screens/movement_list_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_detail_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_form_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_list_screen.dart';
import 'package:stockly/features/products/presentation/screens/stock_adjustment_screen.dart';
import 'package:stockly/features/products/presentation/screens/stock_count_screen.dart';
import 'package:stockly/features/products/presentation/screens/unit_form_screen.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_state.dart';
import 'package:stockly/features/splash/presentation/screens/splash_screen.dart';

/// Every route of design §3.1. Sprint 4 screens (dashboard, sales) show a
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
    builder: (context, state) => ProductListScreen(
      initialQuery: ProductQuery(
        lowStock:
            state.uri.queryParameters[RoutePaths.lowStockParameter] ==
            RoutePaths.trueValue,
        includeArchived:
            state.uri.queryParameters[RoutePaths.archivedParameter] ==
            RoutePaths.trueValue,
      ),
    ),
    routes: [
      _screen(
        RoutePaths.productCreate,
        RouteNames.productCreate,
        RoutePaths.products,
        (state) => const ProductFormScreen(),
      ),
      _screen(
        RoutePaths.productDetail,
        RouteNames.productDetail,
        RoutePaths.products,
        (state) => ProductDetailScreen(productId: _productId(state)),
        routes: [
          _screen(
            RoutePaths.productEdit,
            RouteNames.productEdit,
            RoutePaths.productDetail,
            (state) => ProductFormScreen(productId: _productId(state)),
          ),
          _screen(
            RoutePaths.unitCreate,
            RouteNames.unitCreate,
            RoutePaths.productDetail,
            (state) => UnitFormScreen(productId: _productId(state)),
          ),
          _screen(
            RoutePaths.unitEdit,
            RouteNames.unitEdit,
            RoutePaths.productDetail,
            (state) => UnitFormScreen(
              productId: _productId(state),
              unitId: state.pathParameters[RoutePaths.unitIdParameter],
            ),
          ),
          _screen(
            RoutePaths.stockAdjust,
            RouteNames.stockAdjust,
            RoutePaths.productDetail,
            (state) => StockAdjustmentScreen(productId: _productId(state)),
          ),
          _screen(
            RoutePaths.stockCount,
            RouteNames.stockCount,
            RoutePaths.productDetail,
            (state) => StockCountScreen(productId: _productId(state)),
          ),
          _screen(
            RoutePaths.movements,
            RouteNames.movements,
            RoutePaths.productDetail,
            (state) => MovementListScreen(productId: _productId(state)),
          ),
        ],
      ),
    ],
  );

  static String _productId(GoRouterState state) =>
      state.pathParameters[RoutePaths.productIdParameter]!;

  /// A built route under [parent].
  GoRoute _screen(
    String path,
    String name,
    String parent,
    Widget Function(GoRouterState state) build, {
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: _child(path, parent),
    name: name,
    builder: (context, state) => build(state),
    routes: routes,
  );

  GoRoute get _invoicesRoute => GoRoute(
    path: RoutePaths.invoices,
    name: RouteNames.invoices,
    builder: (context, state) => InvoiceListScreen(
      initialStatus: InvoiceRouteQuery.parse(
        state.uri.queryParameters[RoutePaths.statusParameter],
      ),
    ),
    routes: [
      GoRoute(
        path: _child(RoutePaths.scanCapture, RoutePaths.invoices),
        name: RouteNames.scanCapture,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScanCaptureScreen(),
      ),
      _screen(
        RoutePaths.scanQueue,
        RouteNames.scanQueue,
        RoutePaths.invoices,
        (state) => const ScanQueueScreen(),
      ),
      _screen(
        RoutePaths.invoiceDetail,
        RouteNames.invoiceDetail,
        RoutePaths.invoices,
        (state) => InvoiceDetailScreen(invoiceId: _invoiceId(state)),
        routes: [
          GoRoute(
            path: _child(RoutePaths.invoiceReview, RoutePaths.invoiceDetail),
            name: RouteNames.invoiceReview,
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                InvoiceReviewScreen(invoiceId: _invoiceId(state)),
            routes: [
              GoRoute(
                path: _child(
                  RoutePaths.invoiceLineEdit,
                  RoutePaths.invoiceReview,
                ),
                name: RouteNames.invoiceLineEdit,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final lineNo = int.tryParse(
                    state.pathParameters[RoutePaths.lineNoParameter] ?? '',
                  );
                  return lineNo == null || lineNo < 1
                      ? NotFoundScreen(
                          onGoHome: () => context.go(RoutePaths.home),
                        )
                      : InvoiceLineEditorScreen(
                          invoiceId: _invoiceId(state),
                          lineNo: lineNo,
                        );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static String _invoiceId(GoRouterState state) =>
      state.pathParameters[RoutePaths.invoiceIdParameter]!;

  GoRoute get _settingsRoute => GoRoute(
    path: RoutePaths.settings,
    name: RouteNames.settings,
    builder: (context, state) => const SettingsScreen(),
  );
}
