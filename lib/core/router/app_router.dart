import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/auth_redirect.dart';
import 'package:stockly/core/router/fade_through_branches.dart';
import 'package:stockly/core/router/home_shell.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/router/router_refresh.dart';
import 'package:stockly/core/router/stockly_pages.dart';
import 'package:stockly/core/widgets/not_found_screen.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/login_screen.dart';
import 'package:stockly/features/auth/presentation/screens/register_screen.dart';
import 'package:stockly/features/auth/presentation/screens/shop_suspended_screen.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:stockly/features/dashboard/presentation/screens/expiring_soon_screen.dart';
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
import 'package:stockly/features/sales/presentation/screens/quick_sale_screen.dart';
import 'package:stockly/features/sales/presentation/screens/sale_detail_screen.dart';
import 'package:stockly/features/sales/presentation/screens/sale_list_screen.dart';
import 'package:stockly/features/settings/presentation/screens/profile_screen.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_state.dart';
import 'package:stockly/features/splash/presentation/screens/splash_screen.dart';

/// Every route of design §3.1. The shell has five tabs: dashboard (home),
/// products, invoices, sales and profile; settings live under the profile.
/// Pushed screens slide in from the end edge, top-level screens and tab
/// switches fade through (design-refresh brief).
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

/// The route tree. Full-screen flows (capture, review, quick sale) use the
/// root navigator so the tab bar is hidden.
final class _RouteTable {
  new(this.rootNavigatorKey);

  final GlobalKey<NavigatorState> rootNavigatorKey;

  List<RouteBase> get all => [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      pageBuilder: (context, state) =>
          StocklyPages.fadeThrough(context, state, const SplashScreen()),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      pageBuilder: (context, state) =>
          StocklyPages.fadeThrough(context, state, const LoginScreen()),
    ),
    GoRoute(
      path: RoutePaths.register,
      name: RouteNames.register,
      pageBuilder: (context, state) =>
          StocklyPages.fadeThrough(context, state, const RegisterScreen()),
    ),
    GoRoute(
      path: RoutePaths.suspended,
      name: RouteNames.suspended,
      pageBuilder: (context, state) =>
          StocklyPages.fadeThrough(context, state, const ShopSuspendedScreen()),
    ),
    GoRoute(
      path: RoutePaths.legacySettings,
      redirect: (context, state) => RoutePaths.settings,
    ),
    StatefulShellRoute(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      navigatorContainerBuilder: (context, navigationShell, children) =>
          FadeThroughBranches(
            currentIndex: navigationShell.currentIndex,
            children: children,
          ),
      branches: [
        StatefulShellBranch(routes: [_dashboardRoute]),
        StatefulShellBranch(routes: [_productsRoute]),
        StatefulShellBranch(routes: [_invoicesRoute]),
        StatefulShellBranch(routes: [_salesRoute]),
        StatefulShellBranch(routes: [_profileRoute]),
      ],
    ),
  ];

  GoRoute get _dashboardRoute => GoRoute(
    path: RoutePaths.dashboard,
    name: RouteNames.dashboard,
    builder: (context, state) => const DashboardScreen(),
    routes: [
      _screen(
        RoutePaths.expiringSoon,
        RouteNames.expiringSoon,
        RoutePaths.dashboard,
        (state) => ExpiringSoonScreen(initialDays: _days(state)),
      ),
    ],
  );

  /// The `days` query: one of the offered windows, else the default.
  static int _days(GoRouterState state) {
    final days = int.tryParse(
      state.uri.queryParameters[RoutePaths.daysParameter] ?? '',
    );
    return ExpiringSoonWindow.choices.contains(days)
        ? days!
        : ExpiringSoonWindow.defaultDays;
  }

  GoRoute get _salesRoute => GoRoute(
    path: RoutePaths.sales,
    name: RouteNames.sales,
    builder: (context, state) => const SaleListScreen(),
    routes: [
      GoRoute(
        path: _child(RoutePaths.quickSale, RoutePaths.sales),
        name: RouteNames.quickSale,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            StocklyPages.push(context, state, const QuickSaleScreen()),
      ),
      _screen(
        RoutePaths.saleDetail,
        RouteNames.saleDetail,
        RoutePaths.sales,
        (state) => SaleDetailScreen(
          saleId: state.pathParameters[RoutePaths.saleIdParameter]!,
          alreadyRecorded:
              state.uri.queryParameters[RoutePaths.repeatParameter] ==
              RoutePaths.trueValue,
        ),
      ),
    ],
  );

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
    pageBuilder: (context, state) =>
        StocklyPages.push(context, state, build(state)),
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
        pageBuilder: (context, state) =>
            StocklyPages.push(context, state, const ScanCaptureScreen()),
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
            pageBuilder: (context, state) => StocklyPages.push(
              context,
              state,
              InvoiceReviewScreen(invoiceId: _invoiceId(state)),
            ),
            routes: [
              GoRoute(
                path: _child(
                  RoutePaths.invoiceLineEdit,
                  RoutePaths.invoiceReview,
                ),
                name: RouteNames.invoiceLineEdit,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final lineNo = int.tryParse(
                    state.pathParameters[RoutePaths.lineNoParameter] ?? '',
                  );
                  return StocklyPages.push(
                    context,
                    state,
                    lineNo == null || lineNo < 1
                        ? NotFoundScreen(
                            onGoHome: () => context.go(RoutePaths.home),
                          )
                        : InvoiceLineEditorScreen(
                            invoiceId: _invoiceId(state),
                            lineNo: lineNo,
                          ),
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

  GoRoute get _profileRoute => GoRoute(
    path: RoutePaths.profile,
    name: RouteNames.profile,
    builder: (context, state) => const ProfileScreen(),
    routes: [
      _screen(
        RoutePaths.settings,
        RouteNames.settings,
        RoutePaths.profile,
        (state) => const SettingsScreen(),
      ),
    ],
  );
}
