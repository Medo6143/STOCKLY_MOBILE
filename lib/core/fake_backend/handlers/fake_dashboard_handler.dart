import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/fake_invoice_records.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/handlers/fake_invoices_handler.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// One D2 row before paging.
typedef _Expiring = ({
  FakeProduct product,
  FakeInvoice invoice,
  FakeInvoiceItem line,
  FakeUnit unit,
});

/// Fake D1–D2 (contract §8), computed from the fake state: the counts of
/// non-archived products, today's sales by the Cairo day, the invoices
/// awaiting review, and the confirmed lines that expire within the window
/// (or already expired) whose product still has stock and is not archived.
final class FakeDashboardHandler implements FakeHandler {
  new({
    required this._state,
    required this._clock,
    required this._problems,
    required this._authenticate,
    required this._settleInvoices,
  });

  final FakeBackendState _state;
  final Clock _clock;
  final FakeProblems _problems;
  final FakeAccessToken? Function(FakeRequest request) _authenticate;

  /// Applies finished fake extractions before counting (the invoices
  /// handler owns that transition).
  final void Function(String shopId) _settleInvoices;

  static const int _defaultDays = 60;
  static const int _minDays = 1;
  static const int _maxDays = 365;
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;
  static const int _moneyScale = 2;
  static const int _quantityScale = 3;

  @override
  List<FakeRoute> get routes => [
    FakeRoute('GET', ApiPaths.dashboardSummary, (r) => _guard(r, _summary)),
    FakeRoute(
      'GET',
      ApiPaths.dashboardExpiringSoon,
      (r) => _guard(r, _expiringSoon),
    ),
  ];

  FakeResponse _guard(
    FakeRequest request,
    FakeResponse Function(FakeRequest request, String shopId) handle,
  ) {
    final access = _authenticate(request);
    final shop = access == null ? null : _state.shopById(access.shopId);
    if (access == null || shop == null) {
      return _error(request, ApiErrorCode.authUnauthenticated);
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _error(request, ApiErrorCode.shopSuspended);
    }
    return handle(request, access.shopId);
  }

  // D1
  FakeResponse _summary(FakeRequest request, String shopId) {
    _settleInvoices(shopId);
    final now = _clock.now();
    final today = FakeCairoTime.dayOf(now);
    final products = _state.products
        .where((p) => p.shopId == shopId && !p.isArchived)
        .toList();
    final sales = _state.sales
        .where(
          (s) =>
              s.shopId == shopId && FakeCairoTime.dayOf(s.createdAt) == today,
        )
        .toList();
    return FakeResponse.json(HttpStatus.ok, {
      'productCount': products.length,
      'lowStockCount': products.where((p) => p.isLowStock).length,
      'negativeStockCount': products
          .where((p) => p.quantity < Decimal.zero)
          .length,
      'expiringSoonCount': _expiring(shopId, _defaultDays).length,
      'todaySales': {
        'count': sales.length,
        'total': sales
            .fold(Decimal.zero, (sum, sale) => sum + sale.totalAmount)
            .toStringAsFixed(_moneyScale),
        'overriddenSalesCount': sales.where((s) => s.priceOverridden).length,
      },
      'invoicesAwaitingReview': _state.invoices
          .where(
            (i) =>
                i.shopId == shopId &&
                i.status == FakeInvoiceStatuses.needsReview,
          )
          .length,
      'generatedAt': now.toUtc().toIso8601String(),
    });
  }

  // D2
  FakeResponse _expiringSoon(FakeRequest request, String shopId) {
    final errors = <String, List<String>>{};
    final days = _int(request, ApiQuery.days, _defaultDays, errors);
    final page = _int(request, ApiQuery.page, _defaultPage, errors);
    final pageSize = _int(request, ApiQuery.pageSize, _defaultPageSize, errors);
    if (days != null && (days < _minDays || days > _maxDays)) {
      errors[ApiQuery.days] = [FakeMessages.invalidValue(request.language)];
    }
    if (page != null && page < 1) {
      errors[ApiQuery.page] = [FakeMessages.invalidValue(request.language)];
    }
    if (pageSize != null && (pageSize < 1 || pageSize > _maxPageSize)) {
      errors[ApiQuery.pageSize] = [FakeMessages.invalidValue(request.language)];
    }
    if (errors.isNotEmpty || days == null || page == null || pageSize == null) {
      return _problems.validation(request, errors);
    }
    final rows = _expiring(shopId, days);
    return FakeResponse.json(HttpStatus.ok, {
      'items': [
        for (final row in rows.skip((page - 1) * pageSize).take(pageSize))
          {
            'productId': row.product.id,
            'productName': row.product.name,
            'expiryDate': row.line.expiryDate,
            'batchNo': row.line.batchNo,
            'invoiceId': row.invoice.id,
            'lineQuantity': (row.line.quantity * row.unit.factor)
                .round(scale: _quantityScale)
                .toStringAsFixed(_quantityScale),
            'currentQuantity': row.product.quantity.toStringAsFixed(
              _quantityScale,
            ),
          },
      ],
      'page': page,
      'pageSize': pageSize,
      'totalCount': rows.length,
    });
  }

  /// Confirmed lines of [shopId] expiring up to [days] days after today
  /// (Cairo), already expired ones included, whose product still has stock
  /// and is not archived; by expiry date, product name, then line id (like
  /// the backend).
  List<_Expiring> _expiring(String shopId, int days) {
    final now = _clock.now();
    final last = FakeCairoTime.dayOf(now.add(Duration(days: days)));
    final rows = <_Expiring>[];
    for (final invoice in _state.invoices) {
      if (invoice.shopId != shopId ||
          invoice.status != FakeInvoiceStatuses.confirmed) {
        continue;
      }
      for (final line in invoice.items) {
        final expiry = line.expiryDate;
        final product = _state.productOf(shopId, line.productId);
        if (expiry == null ||
            product == null ||
            product.isArchived ||
            product.quantity <= Decimal.zero ||
            expiry.compareTo(last) > 0) {
          continue;
        }
        rows.add((
          product: product,
          invoice: invoice,
          line: line,
          unit: product.unitById(line.productUnitId) ?? product.baseUnit,
        ));
      }
    }
    return rows..sort((a, b) {
      final byDate = a.line.expiryDate!.compareTo(b.line.expiryDate!);
      if (byDate != 0) {
        return byDate;
      }
      final byName = a.product.name.compareTo(b.product.name);
      return byName != 0 ? byName : a.line.id.compareTo(b.line.id);
    });
  }

  int? _int(
    FakeRequest request,
    String name,
    int fallback,
    Map<String, List<String>> errors,
  ) {
    final raw = request.query[name];
    if (raw == null) {
      return fallback;
    }
    final value = int.tryParse(raw);
    if (value == null) {
      errors[name] = [FakeMessages.invalidValue(request.language)];
    }
    return value;
  }

  FakeResponse _error(FakeRequest request, ApiErrorCode code) =>
      _problems.problem(request, FakeProblems.statusOf(code), code);
}
