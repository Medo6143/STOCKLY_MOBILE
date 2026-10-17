import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/fake_sale_records.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// A checked S1 line, before the product checks.
typedef _SaleLine = ({
  String productId,
  String productUnitId,
  Decimal quantity,
  Decimal? unitPrice,
});

/// Fake S1–S3 (contract §7): `clientRequestId` idempotency (`201` new,
/// `200` repeat), the backend's validation order (shape, precision, then
/// the lines in request order), stock taken out through movements, list
/// price and override per line, and `Stock.NegativeBalance` warnings that
/// never block the sale.
final class FakeSalesHandler implements FakeHandler {
  new({
    required this._state,
    required this._clock,
    required this._uuid,
    required this._problems,
    required this._authenticate,
  });

  final FakeBackendState _state;
  final Clock _clock;
  final UuidGenerator _uuid;
  final FakeProblems _problems;
  final FakeAccessToken? Function(FakeRequest request) _authenticate;

  static const String _sale = '${ApiPaths.sales}/{id}';
  static const String _idParam = 'id';
  static const String _location = 'Location';
  static const String _negativeBalance = 'Stock.NegativeBalance';
  static const int _maxLines = 100;
  static const int _noteMax = 500;
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;
  static const int _moneyScale = 2;
  static const int _quantityScale = 3;
  static final Decimal _moneyLimit = Decimal.parse('10000000000000000');
  static final Decimal _quantityLimit = Decimal.parse('100000000000');
  static final RegExp _decimal = RegExp(r'^-?[0-9]{1,17}(\.[0-9]+)?$');
  static final RegExp _uuidPattern = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  @override
  List<FakeRoute> get routes => [
    FakeRoute('POST', ApiPaths.sales, (r) => _guard(r, _create)),
    FakeRoute('GET', ApiPaths.sales, (r) => _guard(r, _list)),
    FakeRoute('GET', _sale, (r) => _guard(r, _get)),
  ];

  /// `401` without a valid token, `403 Shop.Suspended`. The shop comes
  /// from the token only.
  FakeResponse _guard(
    FakeRequest request,
    FakeResponse Function(FakeRequest request, FakeAccessToken access) handle,
  ) {
    final access = _authenticate(request);
    final shop = access == null ? null : _state.shopById(access.shopId);
    if (access == null || shop == null) {
      return _error(request, ApiErrorCode.authUnauthenticated);
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _error(request, ApiErrorCode.shopSuspended);
    }
    return handle(request, access);
  }

  // S1
  FakeResponse _create(FakeRequest request, FakeAccessToken access) {
    final json = request.jsonObject ?? const <String, Object?>{};
    final language = request.language;
    final errors = <String, List<String>>{};
    final clientRequestId = json['clientRequestId'];
    if (clientRequestId is! String || !_uuidPattern.hasMatch(clientRequestId)) {
      errors['clientRequestId'] = [
        if (clientRequestId == null)
          FakeMessages.required(language)
        else
          FakeMessages.invalidValue(language),
      ];
    }
    final note = json['note'];
    if (note != null && (note is! String || note.length > _noteMax)) {
      errors['note'] = [FakeMessages.tooLong(language, _noteMax)];
    }
    final rawItems = json['items'];
    if (rawItems is! List<Object?> ||
        rawItems.isEmpty ||
        rawItems.length > _maxLines) {
      errors['items'] = [
        if (rawItems == null)
          FakeMessages.required(language)
        else
          FakeMessages.invalidValue(language),
      ];
    } else {
      for (var i = 0; i < rawItems.length; i++) {
        _shape(rawItems[i], 'items[$i]', errors, language);
      }
    }
    if (errors.isNotEmpty) {
      return _problems.validation(request, errors);
    }
    final items = rawItems! as List<Object?>;
    final lines = <_SaleLine>[];
    for (final raw in items) {
      final item = raw! as Map<String, Object?>;
      final quantity = item['quantity']! as String;
      final price = item['unitPrice'] as String?;
      final code =
          _precision(quantity, _quantityScale, _quantityLimit) ??
          (price == null ? null : _precision(price, _moneyScale, _moneyLimit));
      if (code != null) {
        return _error(request, code);
      }
      lines.add((
        productId: (item['productId']! as String).toLowerCase(),
        productUnitId: (item['productUnitId']! as String).toLowerCase(),
        quantity: Decimal.parse(quantity),
        unitPrice: price == null ? null : Decimal.parse(price),
      ));
    }
    final id = (clientRequestId! as String).toLowerCase();
    final repeat = _state.sales
        .where((s) => s.shopId == access.shopId && s.clientRequestId == id)
        .firstOrNull;
    if (repeat != null) {
      return FakeResponse.json(HttpStatus.ok, _saleJson(repeat));
    }
    for (final line in lines) {
      final code = _lineError(access.shopId, line);
      if (code != null) {
        return _error(request, code);
      }
    }
    final sale = _record(access, id, note as String?, lines);
    return FakeResponse(
      HttpStatus.created,
      json: _saleJson(sale),
      headers: {_location: '${ApiPaths.sales}/${sale.id}'},
    );
  }

  /// The FluentValidation shape of one S1 line: ids, a well-formed
  /// quantity greater than zero, an optional well-formed price.
  void _shape(
    Object? raw,
    String path,
    Map<String, List<String>> errors,
    String language,
  ) {
    if (raw is! Map<String, Object?>) {
      errors[path] = [FakeMessages.invalidValue(language)];
      return;
    }
    for (final field in ['productId', 'productUnitId']) {
      final value = raw[field];
      if (value is! String || !_uuidPattern.hasMatch(value)) {
        errors['$path.$field'] = [
          if (value == null)
            FakeMessages.required(language)
          else
            FakeMessages.invalidValue(language),
        ];
      }
    }
    final quantity = raw['quantity'];
    if (quantity is! String || !_decimal.hasMatch(quantity)) {
      errors['$path.quantity'] = [FakeMessages.decimalFormat(language)];
    } else if (Decimal.parse(quantity) <= Decimal.zero) {
      errors['$path.quantity'] = [FakeMessages.invalidValue(language)];
    }
    final price = raw['unitPrice'];
    if (price != null && (price is! String || !_decimal.hasMatch(price))) {
      errors['$path.unitPrice'] = [FakeMessages.decimalFormat(language)];
    }
  }

  /// The backend's `DecimalInput` after the shape: negative, decimals
  /// (never rounded), then the column range.
  ApiErrorCode? _precision(String text, int scale, Decimal limit) {
    final value = Decimal.parse(text);
    if (value < Decimal.zero) {
      return ApiErrorCode.precisionNegative;
    }
    if (value.scale > scale) {
      return ApiErrorCode.precisionTooManyDecimals;
    }
    return value.abs() < limit ? null : ApiErrorCode.precisionOutOfRange;
  }

  /// The checks of one line in the backend's order: the product, its
  /// unit, then that it is not archived.
  ApiErrorCode? _lineError(String shopId, _SaleLine line) {
    final product = _state.productOf(shopId, line.productId);
    if (product == null) {
      return ApiErrorCode.productNotFound;
    }
    if (product.unitById(line.productUnitId) == null) {
      final elsewhere = _state.products
          .where((p) => p.shopId == shopId)
          .any((p) => p.unitById(line.productUnitId) != null);
      return elsewhere
          ? ApiErrorCode.saleUnitNotOfProduct
          : ApiErrorCode.productUnitNotFound;
    }
    return product.isArchived ? ApiErrorCode.saleArchivedProduct : null;
  }

  FakeSale _record(
    FakeAccessToken access,
    String clientRequestId,
    String? note,
    List<_SaleLine> lines,
  ) {
    final now = _clock.now();
    final saleId = _uuid.v4();
    final items = <FakeSaleItem>[];
    final negative = <String>[];
    for (final line in lines) {
      final product = _state.productOf(access.shopId, line.productId)!;
      final unit = product.unitById(line.productUnitId)!;
      final price = line.unitPrice ?? unit.sellPrice;
      _state
        ..recordMovement(
          product,
          id: _uuid.v4(),
          change: -_toBase(line.quantity, unit),
          reason: FakeMovementReasons.sale,
          userId: access.userId,
          at: now,
          saleId: saleId,
        )
        ..unitsInUse.add(unit.id);
      items.add(
        FakeSaleItem(
          id: _uuid.v4(),
          productId: product.id,
          productUnitId: unit.id,
          productName: product.name,
          unitName: unit.name,
          quantity: line.quantity,
          listUnitPrice: unit.sellPrice,
          unitPrice: price,
          lineTotal: (line.quantity * price).round(scale: _moneyScale),
          balanceAfter: product.quantity,
        ),
      );
    }
    for (final item in items) {
      final product = _state.productOf(access.shopId, item.productId)!;
      if (product.quantity < Decimal.zero &&
          !negative.contains(item.productId)) {
        negative.add(item.productId);
      }
    }
    final sale = FakeSale(
      id: saleId,
      shopId: access.shopId,
      clientRequestId: clientRequestId,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      items: items,
      createdAt: now,
      createdByUserId: access.userId,
      negativeProductIds: negative,
    );
    _state.sales.add(sale);
    return sale;
  }

  /// `ProductUnit.ToBase`: rounded to 3 decimals, half away from zero.
  static Decimal _toBase(Decimal quantity, FakeUnit unit) =>
      (quantity * unit.factor).round(scale: _quantityScale);

  // S2
  FakeResponse _list(FakeRequest request, FakeAccessToken access) {
    final errors = <String, List<String>>{};
    final from = _timestamp(request, ApiQuery.from, errors);
    final to = _timestamp(request, ApiQuery.to, errors);
    if (from != null && to != null && to.isBefore(from)) {
      errors[ApiQuery.to] = [FakeMessages.invalidValue(request.language)];
    }
    final page = _int(request, ApiQuery.page, _defaultPage, errors);
    final pageSize = _int(request, ApiQuery.pageSize, _defaultPageSize, errors);
    if (page != null && page < 1) {
      errors[ApiQuery.page] = [FakeMessages.invalidValue(request.language)];
    }
    if (pageSize != null && (pageSize < 1 || pageSize > _maxPageSize)) {
      errors[ApiQuery.pageSize] = [FakeMessages.invalidValue(request.language)];
    }
    if (errors.isNotEmpty || page == null || pageSize == null) {
      return _problems.validation(request, errors);
    }
    final rows =
        _state.sales
            .where((s) => s.shopId == access.shopId)
            .where((s) => from == null || !s.createdAt.isBefore(from))
            .where((s) => to == null || !s.createdAt.isAfter(to))
            .toList()
          ..sort((a, b) {
            final byDate = b.createdAt.compareTo(a.createdAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    return FakeResponse.json(HttpStatus.ok, {
      'items': [
        for (final sale in rows.skip((page - 1) * pageSize).take(pageSize))
          {
            'id': sale.id,
            'totalAmount': _format(sale.totalAmount, _moneyScale),
            'itemCount': sale.items.length,
            'createdAt': _iso(sale.createdAt),
          },
      ],
      'page': page,
      'pageSize': pageSize,
      'totalCount': rows.length,
    });
  }

  // S3
  FakeResponse _get(FakeRequest request, FakeAccessToken access) {
    final id = request.params[_idParam];
    final sale = _state.sales
        .where((s) => s.id == id && s.shopId == access.shopId)
        .firstOrNull;
    return sale == null
        ? _error(request, ApiErrorCode.saleNotFound)
        : FakeResponse.json(HttpStatus.ok, _saleJson(sale));
  }

  DateTime? _timestamp(
    FakeRequest request,
    String name,
    Map<String, List<String>> errors,
  ) {
    final raw = request.query[name];
    if (raw == null) {
      return null;
    }
    final value = DateTime.tryParse(raw);
    if (value == null) {
      errors[name] = [FakeMessages.invalidValue(request.language)];
    }
    return value?.toUtc();
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

  static String _format(Decimal value, int scale) =>
      value.toStringAsFixed(scale);

  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  Map<String, Object?> _saleJson(FakeSale sale) => {
    'id': sale.id,
    'clientRequestId': sale.clientRequestId,
    'totalAmount': _format(sale.totalAmount, _moneyScale),
    'note': sale.note,
    'priceOverridden': sale.priceOverridden,
    'items': [
      for (final item in sale.items)
        {
          'id': item.id,
          'productId': item.productId,
          'productName': item.productName,
          'productUnitId': item.productUnitId,
          'unitName': item.unitName,
          'quantity': _format(item.quantity, _quantityScale),
          'listUnitPrice': _format(item.listUnitPrice, _moneyScale),
          'unitPrice': _format(item.unitPrice, _moneyScale),
          'priceOverridden': item.priceOverridden,
          'lineTotal': _format(item.lineTotal, _moneyScale),
          'balanceAfter': _format(item.balanceAfter, _quantityScale),
        },
    ],
    'createdAt': _iso(sale.createdAt),
    'createdByUserId': sale.createdByUserId,
    'warnings': [
      for (final productId in sale.negativeProductIds)
        {'code': _negativeBalance, 'productId': productId},
    ],
  };
}
