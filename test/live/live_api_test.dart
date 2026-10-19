@Tags(['live'])
library;

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stockly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:stockly/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:stockly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:stockly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/repositories/products_repository_impl.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/sales/data/datasources/pending_sales_local_data_source.dart';
import 'package:stockly/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:stockly/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';

import '../helpers/test_doubles.dart';

/// `--dart-define=STOCKLY_LIVE_API=http://127.0.0.1:5000`.
const String _liveApi = String.fromEnvironment('STOCKLY_LIVE_API');

const String _skipReason =
    'Live API test: run with '
    '`flutter test --tags live --dart-define=STOCKLY_LIVE_API=<base URL>` '
    'against a running backend.';

/// The app's real Dio stack, data sources and repositories against a
/// running backend (opt-in, tag `live`). Tokens live in memory.
void main() {
  setUpAll(() {
    // flutter_test answers every HTTP request with 400; this test needs
    // the real network.
    HttpOverrides.global = null;
  });

  for (final language in AppLanguage.values) {
    test(
      'FullFlow_${language.name}',
      () => _fullFlow(language.name),
      skip: _liveApi.isEmpty ? _skipReason : false,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

T _ok<T>(Result<T, Failure> result, String step) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('$step failed: $failure'),
};

Future<void> _fullFlow(String language) async {
  final random = Random();
  final suffix =
      '${DateTime.now().microsecondsSinceEpoch}${random.nextInt(999)}';
  const uuid = PackageUuidGenerator();
  const logger = NoopLogger();
  const config = AppConfig(backendMode: BackendMode.real, apiBaseUrl: _liveApi);
  final tokens = InMemoryTokenStorage();
  final signals = SessionSignals();
  addTearDown(signals.close);
  final refresher = TokenRefresher(
    refreshDio: buildRefreshDio(
      config: config,
      uuid: uuid,
      languageCode: () => language,
      logger: logger,
      logRequests: false,
    ),
    tokens: tokens,
    signals: signals,
    leases: ImmediateLeaseService(),
  );
  final dio = buildDio(
    config: config,
    uuid: uuid,
    languageCode: () => language,
    tokens: tokens,
    refresher: refresher,
    signals: signals,
    logger: logger,
    logRequests: false,
  );
  final auth = AuthRepositoryImpl(AuthRemoteDataSource(dio), tokens);
  final products = ProductsRepositoryImpl(ProductsRemoteDataSource(dio));
  final email = 'live-$suffix@stockly.test';
  const password = 'Str0ngPass1';

  // Register a new shop, then log in and confirm the session (A1, A2, A5).
  final registered = _ok(
    await auth.register(
      RegisterInput(
        fullName: 'Live Test',
        email: email,
        password: password,
        preferredLanguage: AppLanguage.values.byName(language),
        shopName: 'صيدلية الاختبار $suffix',
        shopType: ShopType.pharmacy,
      ),
    ),
    'register',
  );
  expect(registered.shop.role, ShopRole.owner);
  _ok(await auth.login(email: email, password: password), 'login');
  final me = _ok(await auth.restoreSession(), 'me');
  expect(me.user.email, email);

  // A product with opening stock, a unit, an adjustment, a count (P3, P6,
  // P9, P10).
  final barcode = '62${suffix.substring(suffix.length - 11)}';
  ProductDraft draft() => ProductDraft(
    name: 'بنادول اكسترا $suffix',
    barcode: barcode,
    category: 'مسكنات',
    baseUnitName: 'شريط',
    costPrice: Money.fromApi('12.50'),
    baseUnitSellPrice: Money.fromApi('15.00'),
    lowStockThreshold: Quantity.fromApi('5.000'),
    openingQuantity: Quantity.fromApi('24.000'),
  );
  final product = _ok(await products.createProduct(draft()), 'create');
  expect(product.quantity, Quantity.fromApi('24.000'));
  _ok(
    await products.addUnit(
      product.id,
      UnitDraft(
        name: 'علبة',
        factor: UnitFactor.fromApi('3.000000'),
        sellPrice: Money.fromApi('40.00'),
        barcode: null,
      ),
    ),
    'add unit',
  );
  final adjusted = _ok(
    await products.adjustStock(
      product.id,
      StockAdjustmentDraft(
        quantityChange: Quantity.fromApi('-2.000'),
        unitId: null,
        note: 'Live test',
      ),
    ),
    'adjust',
  );
  expect(adjusted.balanceAfter, Quantity.fromApi('22.000'));
  final counted = _ok(
    await products.recordStockCount(
      product.id,
      StockCountDraft(countedQuantity: Quantity.fromApi('4.000'), unitId: null),
    ),
    'count',
  );
  expect(counted.changed, isTrue);
  expect(counted.quantity, Quantity.fromApi('4.000'));

  // Low stock list and movements newest first (P1, P11).
  final lowStock = _ok(
    await products.getProducts(
      const ProductQuery(lowStock: true),
      page: 1,
      pageSize: 100,
    ),
    'low stock',
  );
  expect(lowStock.items.map((p) => p.id), contains(product.id));
  final movements = _ok(
    await products.getMovements(product.id, page: 1, pageSize: 20),
    'movements',
  );
  expect(movements.items.map((m) => m.reason), [
    StockMovementReason.stockCount,
    StockMovementReason.manualAdjustment,
    StockMovementReason.stockCount,
  ]);
  for (var i = 1; i < movements.items.length; i++) {
    expect(
      movements.items[i - 1].createdAt.isBefore(movements.items[i].createdAt),
      isFalse,
    );
  }

  // A sale of the product, then the same sale again (S1, ADR-0006): the
  // repeat answers 200 with the same sale. Then the sales list and detail
  // (S2, S3), the dashboard (D1, D2) and the barcode lookup (P12).
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final sales = SalesRepositoryImpl(
    remote: SalesRemoteDataSource(dio),
    local: PendingSalesLocalDataSource(
      database.pendingSalesDao,
      const SystemClock(),
    ),
  );
  final saleRequest = SaleRequest(
    clientRequestId: uuid.v4(),
    note: 'Live test',
    items: [
      SaleRequestItem(
        productId: product.id,
        productUnitId: product.baseUnit.id,
        quantity: Quantity.fromApi('1.000'),
        unitPrice: null,
      ),
    ],
  );
  final created = _ok(
    await sales.submit(
      saleRequest,
      shopId: registered.shop.id,
      userId: registered.user.id,
    ),
    'sale',
  );
  expect(created, isA<SaleCreated>());
  expect(created.sale.items.single.balanceAfter, Quantity.fromApi('3.000'));
  final repeat = _ok(
    await sales.submit(
      saleRequest,
      shopId: registered.shop.id,
      userId: registered.user.id,
    ),
    'sale repeat',
  );
  expect(repeat, isA<SaleAlreadyRecorded>());
  expect(repeat.sale.id, created.sale.id);
  expect(await sales.pendingSale(registered.shop.id), isNull);
  final saleList = _ok(
    await sales.getSales(from: null, page: 1, pageSize: 100),
    'sales',
  );
  expect(saleList.items.map((s) => s.id), contains(created.sale.id));
  final saleDetail = _ok(await sales.getSale(created.sale.id), 'sale detail');
  expect(saleDetail.id, created.sale.id);
  expect(saleDetail.items.single.productId, product.id);
  final dashboard = DashboardRepositoryImpl(DashboardRemoteDataSource(dio));
  final summary = _ok(await dashboard.getSummary(), 'dashboard');
  expect(summary.productCount, greaterThanOrEqualTo(1));
  _ok(
    await dashboard.getExpiringSoon(days: 60, page: 1, pageSize: 20),
    'expiring soon',
  );
  // Plans and the new shop's subscription (B1, B2). No checkout: a real
  // payment cannot be made from a test, so B3 is never called here.
  final billing = BillingRepositoryImpl(BillingRemoteDataSource(dio));
  final plans = _ok(await billing.getPlans(), 'plans');
  expect(plans, isNotEmpty);
  expect(plans.where((p) => p.isCurrent), hasLength(1));
  final subscription = _ok(await billing.getSubscription(), 'subscription');
  expect(subscription.plan.isCurrent, isTrue);
  expect(plans.map((p) => p.id), contains(subscription.plan.id));
  expect(subscription.memberCount, greaterThanOrEqualTo(1));
  expect(subscription.pendingPayment, isNull);
  final lookup = _ok(await products.lookupBarcode(barcode), 'lookup');
  expect(lookup.product.id, product.id);
  expect(lookup.unit.isBase, isTrue);

  // A failing request: the code is stable, title/detail follow
  // Accept-Language (contract §1.5).
  final duplicate = await products.createProduct(draft());
  expect(switch (duplicate) {
    Err(:final ApiFailure failure) => failure.code,
    _ => null,
  }, ApiErrorCode.productDuplicateBarcode);
  final problem = await _problemOf(dio, draft());
  final text = '${problem['title']} ${problem['detail']}';
  if (language == 'ar') {
    expect(_hasArabic(text), isTrue, reason: text);
  } else {
    expect(_hasArabic(text), isFalse, reason: text);
  }

  // Refresh rotates the refresh token (A3), then logout (A4).
  final before = (await tokens.read())!;
  final outcome = await refresher.refresh(staleAccessToken: before.accessToken);
  expect(outcome, isA<RefreshSucceeded>());
  final after = (await tokens.read())!;
  expect(after.refreshToken, isNot(before.refreshToken));
  await auth.logout();
  expect(await tokens.read(), isNull);
}

/// `true` when [text] has a letter of the Arabic block (U+0600–U+06FF).
bool _hasArabic(String text) =>
    text.runes.any((rune) => rune >= _arabicFirst && rune <= _arabicLast);

const int _arabicFirst = 0x0600;
const int _arabicLast = 0x06FF;

/// The ProblemDetails body of creating [draft] again (duplicate barcode).
Future<Map<String, Object?>> _problemOf(Dio dio, ProductDraft draft) async {
  try {
    await dio.post<Object?>(
      ApiPaths.products,
      data: {
        'name': draft.name,
        'barcode': draft.barcode,
        'baseUnitName': draft.baseUnitName,
        'costPrice': draft.costPrice.toApi(),
        'baseUnitSellPrice': draft.baseUnitSellPrice.toApi(),
      },
    );
  } on DioException catch (e) {
    return e.response?.data as Map<String, Object?>? ?? const {};
  }
  throw TestFailure('The duplicate barcode was accepted.');
}
