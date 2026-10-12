import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/fake_text.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// The signed-in caller of a products request; the shop comes only from
/// the access token (contract §1.4).
final class _Caller {
  const new({
    required this.userId,
    required this.shopId,
    required this.isOwner,
  });

  final String userId;
  final String shopId;
  final bool isOwner;
}

/// The P6/P7 body after the shape and precision checks; `problem` is set
/// when the request must be rejected.
typedef _UnitInput = ({
  String name,
  Decimal factor,
  Decimal sellPrice,
  String? barcode,
  FakeResponse? problem,
});

/// Which signs a decimal request field accepts (like the backend's
/// decimal input rules).
enum _Sign { any, nonNegative, positive }

/// A parsed decimal request field, or the problem to answer with.
final class _Parsed {
  const new ok(Decimal this.value) : error = null;

  const new failed(ApiErrorCode this.error) : value = null;

  final Decimal? value;
  final ApiErrorCode? error;
}

/// Collects `Validation.Failed` field errors of one request body, like the
/// backend's FluentValidation validators and model binding.
final class _Shape {
  new(this._json, this._language);

  final Map<String, Object?> _json;
  final String _language;
  final Map<String, List<String>> errors = {};

  static final RegExp _decimal = RegExp(r'^-?[0-9]{1,17}(\.[0-9]+)?$');
  static final RegExp _uuid = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// A required string; blank is allowed here (the handler answers it with
  /// its own `*.NameRequired` code).
  String? requiredString(String field) {
    final value = _json[field];
    if (value is String) {
      return value;
    }
    errors[field] = [
      if (value == null)
        FakeMessages.required(_language)
      else
        FakeMessages.invalidValue(_language),
    ];
    return null;
  }

  String? optionalString(String field, {int? max}) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      errors[field] = [FakeMessages.invalidValue(_language)];
      return null;
    }
    if (max != null && value.length > max) {
      errors[field] = [FakeMessages.tooLong(_language, max)];
      return null;
    }
    return value;
  }

  /// A decimal string field; a JSON number is rejected (contract §1.2).
  String? decimal(String field, {required bool required}) {
    final value = _json[field];
    if (value == null) {
      if (required) {
        errors[field] = [FakeMessages.required(_language)];
      }
      return null;
    }
    if (value is! String || !_decimal.hasMatch(value)) {
      errors[field] = [FakeMessages.decimalFormat(_language)];
      return null;
    }
    return value;
  }

  /// An optional unit id (a UUID string).
  String? optionalId(String field) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    if (value is! String || !_uuid.hasMatch(value)) {
      errors[field] = [FakeMessages.invalidValue(_language)];
      return null;
    }
    return value.toLowerCase();
  }
}

/// Fake P1–P12 (contract §5): validation, precision rules, duplicate
/// checks, archive rules, Owner checks, opening stock, movements, low-stock
/// filter, Arabic-normalized search and paging.
final class FakeProductsHandler implements FakeHandler {
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

  static const String _product = '${ApiPaths.products}/{id}';
  static const String _units = '$_product/units';
  static const String _unit = '$_units/{unitId}';
  static const String _idParam = 'id';
  static const String _unitIdParam = 'unitId';

  static const int _searchMax = 100;
  static const int _barcodeMax = 64;
  static const int _categoryMax = 100;
  static const int _noteMax = 500;
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;

  static const int _moneyScale = 2;
  static const int _quantityScale = 3;
  static const int _factorScale = 6;
  static final Decimal _moneyLimit = Decimal.parse('10000000000000000');
  static final Decimal _quantityLimit = Decimal.parse('100000000000');
  static final Decimal _factorLimit = Decimal.parse('100000000');

  static const String _true = 'true';
  static const String _false = 'false';
  static const String _location = 'Location';

  @override
  List<FakeRoute> get routes => [
    FakeRoute('GET', ApiPaths.products, (r) => _guard(r, _list)),
    FakeRoute('POST', ApiPaths.products, (r) => _guard(r, _create)),
    FakeRoute('GET', ApiPaths.productLookup, (r) => _guard(r, _lookup)),
    FakeRoute('GET', _product, (r) => _guard(r, _get)),
    FakeRoute('PUT', _product, (r) => _guard(r, _update)),
    FakeRoute(
      'POST',
      '$_product/archive',
      (r) => _guard(r, _archive, ownerOnly: true),
    ),
    FakeRoute('POST', _units, (r) => _guard(r, _addUnit)),
    FakeRoute('PUT', _unit, (r) => _guard(r, _updateUnit)),
    FakeRoute('DELETE', _unit, (r) => _guard(r, _deleteUnit)),
    FakeRoute(
      'POST',
      '$_product/adjustments',
      (r) => _guard(r, _adjust, ownerOnly: true),
    ),
    FakeRoute(
      'POST',
      '$_product/stock-counts',
      (r) => _guard(r, _count, ownerOnly: true),
    ),
    FakeRoute('GET', '$_product/movements', (r) => _guard(r, _movements)),
  ];

  /// `401` without a valid token, `403 Shop.Suspended`, and `403
  /// Auth.Forbidden` for Staff on owner-only endpoints.
  FakeResponse _guard(
    FakeRequest request,
    FakeResponse Function(FakeRequest request, _Caller caller) handle, {
    bool ownerOnly = false,
  }) {
    final access = _authenticate(request);
    final shop = access == null ? null : _state.shopById(access.shopId);
    if (access == null || shop == null) {
      return _error(request, ApiErrorCode.authUnauthenticated);
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _error(request, ApiErrorCode.shopSuspended);
    }
    final role = _state.membership(access.userId, access.shopId)?.role;
    final caller = _Caller(
      userId: access.userId,
      shopId: access.shopId,
      isOwner: role == FakeRoles.owner,
    );
    if (ownerOnly && !caller.isOwner) {
      return _error(request, ApiErrorCode.authForbidden);
    }
    return handle(request, caller);
  }

  // P1
  FakeResponse _list(FakeRequest request, _Caller caller) {
    final errors = <String, List<String>>{};
    final search = request.query[ApiQuery.search];
    if (search != null && search.length > _searchMax) {
      errors[ApiQuery.search] = [
        FakeMessages.tooLong(request.language, _searchMax),
      ];
    }
    final lowStock = _bool(request, ApiQuery.lowStock, errors);
    final includeArchived = _bool(request, ApiQuery.includeArchived, errors);
    final paging = _paging(request, errors);
    if (errors.isNotEmpty || paging == null) {
      return _problems.validation(request, errors);
    }
    final term = search == null ? '' : FakeText.normalize(search);
    final rows =
        _state.products
            .where((p) => p.shopId == caller.shopId)
            .where((p) => includeArchived || !p.isArchived)
            .where((p) => !lowStock || p.isLowStock)
            .where(
              (p) => term.isEmpty || FakeText.normalize(p.name).contains(term),
            )
            .toList()
          ..sort((a, b) {
            final byName = FakeText.normalize(a.name)
                .compareTo(FakeText.normalize(b.name));
            return byName != 0 ? byName : a.id.compareTo(b.id);
          });
    return FakeResponse.json(HttpStatus.ok, _page(rows, paging, _listItemJson));
  }

  // P2
  FakeResponse _get(FakeRequest request, _Caller caller) {
    final product = _productOf(request, caller);
    return product == null
        ? _error(request, ApiErrorCode.productNotFound)
        : FakeResponse.json(HttpStatus.ok, _detailJson(product));
  }

  // P3
  FakeResponse _create(FakeRequest request, _Caller caller) {
    final shape = _Shape(request.jsonObject ?? const {}, request.language);
    final name = shape.requiredString('name');
    final baseUnitName = shape.requiredString('baseUnitName');
    final cost = shape.decimal('costPrice', required: true);
    final sell = shape.decimal('baseUnitSellPrice', required: true);
    final threshold = shape.decimal('lowStockThreshold', required: false);
    final opening = shape.decimal('openingQuantity', required: false);
    final barcode = shape.optionalString('barcode', max: _barcodeMax);
    final category = shape.optionalString('category', max: _categoryMax);
    if (shape.errors.isNotEmpty ||
        name == null ||
        baseUnitName == null ||
        cost == null ||
        sell == null) {
      return _problems.validation(request, shape.errors);
    }
    if (opening != null && !caller.isOwner) {
      return _error(request, ApiErrorCode.productOpeningStockOwnerOnly);
    }
    final parsed = [
      _money(cost),
      _money(sell),
      if (threshold == null)
        _Parsed.ok(Decimal.zero)
      else
        _quantity(threshold, _Sign.nonNegative),
      if (opening == null)
        _Parsed.ok(Decimal.zero)
      else
        _quantity(opening, _Sign.nonNegative),
    ];
    for (final value in parsed) {
      if (value.error case final code?) {
        return _error(request, code);
      }
    }
    if (_blank(name)) {
      return _error(request, ApiErrorCode.productNameRequired);
    }
    if (_blank(baseUnitName)) {
      return _error(request, ApiErrorCode.productUnitNameRequired);
    }
    final cleanBarcode = _clean(barcode);
    if (cleanBarcode != null &&
        _productBarcodeUsed(caller.shopId, cleanBarcode, exceptId: null)) {
      return _error(request, ApiErrorCode.productDuplicateBarcode);
    }
    final now = _clock.now();
    final product = FakeProduct(
      id: _uuid.v4(),
      shopId: caller.shopId,
      name: name.trim(),
      barcode: cleanBarcode,
      category: _clean(category),
      costPrice: parsed[0].value!,
      lowStockThreshold: parsed[2].value!,
      units: [
        FakeUnit(
          id: _uuid.v4(),
          name: baseUnitName.trim(),
          factor: Decimal.one,
          sellPrice: parsed[1].value!,
          barcode: null,
          isBase: true,
        ),
      ],
      createdAt: now,
    );
    _state.products.add(product);
    final openingQuantity = parsed[3].value!;
    if (openingQuantity > Decimal.zero) {
      _state.recordMovement(
        product,
        id: _uuid.v4(),
        change: openingQuantity,
        reason: FakeMovementReasons.stockCount,
        userId: caller.userId,
        at: now,
        note: FakeMovementReasons.openingStockNote,
      );
    }
    return FakeResponse(
      HttpStatus.created,
      json: _detailJson(product),
      headers: {_location: ApiPaths.product(product.id)},
    );
  }

  // P4
  FakeResponse _update(FakeRequest request, _Caller caller) {
    final shape = _Shape(request.jsonObject ?? const {}, request.language);
    final name = shape.requiredString('name');
    final cost = shape.decimal('costPrice', required: true);
    final threshold = shape.decimal('lowStockThreshold', required: true);
    final barcode = shape.optionalString('barcode', max: _barcodeMax);
    final category = shape.optionalString('category', max: _categoryMax);
    if (shape.errors.isNotEmpty ||
        name == null ||
        cost == null ||
        threshold == null) {
      return _problems.validation(request, shape.errors);
    }
    final parsedCost = _money(cost);
    final parsedThreshold = _quantity(threshold, _Sign.nonNegative);
    for (final value in [parsedCost, parsedThreshold]) {
      if (value.error case final code?) {
        return _error(request, code);
      }
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    if (product.isArchived) {
      return _error(request, ApiErrorCode.productArchived);
    }
    if (_blank(name)) {
      return _error(request, ApiErrorCode.productNameRequired);
    }
    final cleanBarcode = _clean(barcode);
    if (cleanBarcode != null &&
        _productBarcodeUsed(
          caller.shopId,
          cleanBarcode,
          exceptId: product.id,
        )) {
      return _error(request, ApiErrorCode.productDuplicateBarcode);
    }
    product
      ..name = name.trim()
      ..barcode = cleanBarcode
      ..category = _clean(category)
      ..costPrice = parsedCost.value!
      ..lowStockThreshold = parsedThreshold.value!
      ..updatedAt = _clock.now();
    return FakeResponse.json(HttpStatus.ok, _detailJson(product));
  }

  // P5
  FakeResponse _archive(FakeRequest request, _Caller caller) {
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    if (!product.isArchived) {
      product
        ..isArchived = true
        ..updatedAt = _clock.now();
    }
    return const FakeResponse.noContent();
  }

  // P6
  FakeResponse _addUnit(FakeRequest request, _Caller caller) {
    final input = _unitInput(request);
    if (input.problem case final problem?) {
      return problem;
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    if (_unitChangeError(product, input, except: null) case final code?) {
      return _error(request, code);
    }
    final unit = FakeUnit(
      id: _uuid.v4(),
      name: input.name.trim(),
      factor: input.factor,
      sellPrice: input.sellPrice,
      barcode: input.barcode,
      isBase: false,
    );
    product
      ..units.add(unit)
      ..updatedAt = _clock.now();
    return FakeResponse(
      HttpStatus.created,
      json: _unitJson(unit),
      headers: {_location: ApiPaths.productUnit(product.id, unit.id)},
    );
  }

  // P7
  FakeResponse _updateUnit(FakeRequest request, _Caller caller) {
    final input = _unitInput(request);
    if (input.problem case final problem?) {
      return problem;
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    if (product.isArchived) {
      return _error(request, ApiErrorCode.productArchived);
    }
    final unit = product.unitById(request.params[_unitIdParam]);
    if (unit == null) {
      return _error(request, ApiErrorCode.productUnitNotFound);
    }
    if (unit.isBase && input.factor != Decimal.one) {
      return _error(request, ApiErrorCode.productUnitBaseUnitFactorFixed);
    }
    if (_unitChangeError(product, input, except: unit) case final code?) {
      return _error(request, code);
    }
    unit
      ..name = input.name.trim()
      ..factor = input.factor
      ..sellPrice = input.sellPrice
      ..barcode = input.barcode;
    product.updatedAt = _clock.now();
    return FakeResponse.json(HttpStatus.ok, _unitJson(unit));
  }

  // P8
  FakeResponse _deleteUnit(FakeRequest request, _Caller caller) {
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    if (product.isArchived) {
      return _error(request, ApiErrorCode.productArchived);
    }
    final unit = product.unitById(request.params[_unitIdParam]);
    if (unit == null) {
      return _error(request, ApiErrorCode.productUnitNotFound);
    }
    if (unit.isBase) {
      return _error(request, ApiErrorCode.productUnitBaseUnitCannotBeRemoved);
    }
    if (_state.unitsInUse.contains(unit.id)) {
      return _error(request, ApiErrorCode.productUnitInUse);
    }
    product
      ..units.remove(unit)
      ..updatedAt = _clock.now();
    return const FakeResponse.noContent();
  }

  // P9
  FakeResponse _adjust(FakeRequest request, _Caller caller) {
    final shape = _Shape(request.jsonObject ?? const {}, request.language);
    final change = shape.decimal('quantityChange', required: true);
    final unitId = shape.optionalId('unitId');
    final note = shape.optionalString('note', max: _noteMax);
    if (shape.errors.isNotEmpty || change == null) {
      return _problems.validation(request, shape.errors);
    }
    final parsed = _quantity(change, _Sign.any);
    if (parsed.error case final code?) {
      return _error(request, code);
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    final unit = unitId == null ? product.baseUnit : product.unitById(unitId);
    if (unit == null) {
      return _error(request, ApiErrorCode.productUnitNotFound);
    }
    final baseChange = _toBase(parsed.value!, unit);
    if (baseChange == Decimal.zero) {
      return _error(request, ApiErrorCode.stockZeroChange);
    }
    final cleanNote = _clean(note);
    if (cleanNote == null) {
      return _error(request, ApiErrorCode.stockNoteRequired);
    }
    if (!_fits(product.quantity + baseChange, _quantityLimit)) {
      return _error(request, ApiErrorCode.precisionOutOfRange);
    }
    final movement = _state.recordMovement(
      product,
      id: _uuid.v4(),
      change: baseChange,
      reason: FakeMovementReasons.manualAdjustment,
      userId: caller.userId,
      at: _clock.now(),
      note: cleanNote,
    );
    return FakeResponse.json(HttpStatus.created, _movementJson(movement));
  }

  // P10
  FakeResponse _count(FakeRequest request, _Caller caller) {
    final shape = _Shape(request.jsonObject ?? const {}, request.language);
    final counted = shape.decimal('countedQuantity', required: true);
    final unitId = shape.optionalId('unitId');
    if (shape.errors.isNotEmpty || counted == null) {
      return _problems.validation(request, shape.errors);
    }
    final parsed = _quantity(counted, _Sign.nonNegative);
    if (parsed.error case final code?) {
      return _error(request, code);
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    final unit = unitId == null ? product.baseUnit : product.unitById(unitId);
    if (unit == null) {
      return _error(request, ApiErrorCode.productUnitNotFound);
    }
    final baseCount = _toBase(parsed.value!, unit);
    if (!_fits(baseCount, _quantityLimit)) {
      return _error(request, ApiErrorCode.precisionOutOfRange);
    }
    final change = baseCount - product.quantity;
    final movement = change == Decimal.zero
        ? null
        : _state.recordMovement(
            product,
            id: _uuid.v4(),
            change: change,
            reason: FakeMovementReasons.stockCount,
            userId: caller.userId,
            at: _clock.now(),
          );
    return FakeResponse.json(HttpStatus.ok, {
      'changed': movement != null,
      'quantity': _format(product.quantity, _quantityScale),
      'movement': movement == null ? null : _movementJson(movement),
    });
  }

  // P11
  FakeResponse _movements(FakeRequest request, _Caller caller) {
    final errors = <String, List<String>>{};
    final paging = _paging(request, errors);
    if (errors.isNotEmpty || paging == null) {
      return _problems.validation(request, errors);
    }
    final product = _productOf(request, caller);
    if (product == null) {
      return _error(request, ApiErrorCode.productNotFound);
    }
    final rows = _state.movements
        .where((m) => m.productId == product.id)
        .toList()
        .reversed
        .toList();
    return FakeResponse.json(HttpStatus.ok, _page(rows, paging, _movementJson));
  }

  // P12
  FakeResponse _lookup(FakeRequest request, _Caller caller) {
    final barcode = request.query[ApiQuery.barcode]?.trim() ?? '';
    if (barcode.isEmpty) {
      return _problems.validation(request, {
        ApiQuery.barcode: [FakeMessages.required(request.language)],
      });
    }
    for (final product in _state.products) {
      if (product.shopId != caller.shopId || product.isArchived) {
        continue;
      }
      final unit = product.barcode == barcode
          ? product.baseUnit
          : product.units.where((u) => u.barcode == barcode).firstOrNull;
      if (unit != null) {
        return FakeResponse.json(HttpStatus.ok, {
          'product': _listItemJson(product),
          'unit': _unitJson(unit),
        });
      }
    }
    return _error(request, ApiErrorCode.productNotFound);
  }

  FakeProduct? _productOf(FakeRequest request, _Caller caller) =>
      _state.productOf(caller.shopId, request.params[_idParam]);

  _UnitInput _unitInput(FakeRequest request) {
    final shape = _Shape(request.jsonObject ?? const {}, request.language);
    final name = shape.requiredString('name');
    final factor = shape.decimal('factor', required: true);
    final sell = shape.decimal('sellPrice', required: true);
    final barcode = shape.optionalString('barcode', max: _barcodeMax);
    FakeResponse? problem;
    var parsedFactor = Decimal.zero;
    var parsedSell = Decimal.zero;
    if (shape.errors.isNotEmpty ||
        name == null ||
        factor == null ||
        sell == null) {
      problem = _problems.validation(request, shape.errors);
    } else {
      final f = _parse(factor, _factorScale, _Sign.positive, _factorLimit);
      final s = _money(sell);
      final code = f.error ?? s.error;
      if (code != null) {
        problem = _error(request, code);
      } else {
        parsedFactor = f.value!;
        parsedSell = s.value!;
      }
    }
    return (
      name: name ?? '',
      factor: parsedFactor,
      sellPrice: parsedSell,
      barcode: _clean(barcode),
      problem: problem,
    );
  }

  /// The domain checks of adding or changing a unit: archived product,
  /// blank or duplicate name, duplicate barcode (on the product, then in
  /// the whole shop).
  ApiErrorCode? _unitChangeError(
    FakeProduct product,
    _UnitInput input, {
    required FakeUnit? except,
  }) {
    if (product.isArchived) {
      return ApiErrorCode.productArchived;
    }
    if (_blank(input.name)) {
      return ApiErrorCode.productUnitNameRequired;
    }
    final normalized = FakeText.normalize(input.name);
    final others = product.units.where((u) => u != except);
    if (others.any((u) => FakeText.normalize(u.name) == normalized)) {
      return ApiErrorCode.productUnitDuplicateName;
    }
    final barcode = input.barcode;
    if (barcode != null) {
      final usedInShop = _state.products
          .where((p) => p.shopId == product.shopId)
          .expand((p) => p.units)
          .any((u) => u != except && u.barcode == barcode);
      if (usedInShop) {
        return ApiErrorCode.productUnitDuplicateBarcode;
      }
    }
    return null;
  }

  bool _productBarcodeUsed(
    String shopId,
    String barcode, {
    required String? exceptId,
  }) => _state.products.any(
    (p) =>
        p.shopId == shopId &&
        !p.isArchived &&
        p.id != exceptId &&
        p.barcode == barcode,
  );

  bool _bool(
    FakeRequest request,
    String name,
    Map<String, List<String>> errors,
  ) {
    final raw = request.query[name]?.toLowerCase();
    if (raw == null || raw == _false) {
      return false;
    }
    if (raw == _true) {
      return true;
    }
    errors[name] = [FakeMessages.invalidValue(request.language)];
    return false;
  }

  /// `page >= 1` and `pageSize` in `1..100`, never clamped (contract §1.3).
  ({int page, int pageSize})? _paging(
    FakeRequest request,
    Map<String, List<String>> errors,
  ) {
    final page = _int(request, ApiQuery.page, _defaultPage, errors);
    final pageSize = _int(request, ApiQuery.pageSize, _defaultPageSize, errors);
    if (page != null && page < 1) {
      errors[ApiQuery.page] = [FakeMessages.invalidValue(request.language)];
    }
    if (pageSize != null && (pageSize < 1 || pageSize > _maxPageSize)) {
      errors[ApiQuery.pageSize] = [FakeMessages.invalidValue(request.language)];
    }
    return page == null || pageSize == null || errors.isNotEmpty
        ? null
        : (page: page, pageSize: pageSize);
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

  Map<String, Object?> _page<T>(
    List<T> rows,
    ({int page, int pageSize}) paging,
    Map<String, Object?> Function(T row) toJson,
  ) => {
    'items': [
      for (final row
          in rows
              .skip((paging.page - 1) * paging.pageSize)
              .take(paging.pageSize))
        toJson(row),
    ],
    'page': paging.page,
    'pageSize': paging.pageSize,
    'totalCount': rows.length,
  };

  _Parsed _money(String text) =>
      _parse(text, _moneyScale, _Sign.nonNegative, _moneyLimit);

  _Parsed _quantity(String text, _Sign sign) =>
      _parse(text, _quantityScale, sign, _quantityLimit);

  /// The backend's `DecimalInput`: sign first, then decimals (never
  /// rounded), then the column range.
  _Parsed _parse(String text, int maxDecimals, _Sign sign, Decimal limit) {
    final value = Decimal.parse(text);
    final isNegative = value < Decimal.zero;
    final isZero = value == Decimal.zero;
    if (sign == _Sign.nonNegative && isNegative) {
      return const _Parsed.failed(ApiErrorCode.precisionNegative);
    }
    if (sign == _Sign.positive && (isNegative || isZero)) {
      return const _Parsed.failed(ApiErrorCode.precisionNotPositive);
    }
    if (value.scale > maxDecimals) {
      return const _Parsed.failed(ApiErrorCode.precisionTooManyDecimals);
    }
    if (!_fits(value, limit)) {
      return const _Parsed.failed(ApiErrorCode.precisionOutOfRange);
    }
    return _Parsed.ok(value);
  }

  bool _fits(Decimal value, Decimal limit) => value.abs() < limit;

  /// `ProductUnit.ToBase`: rounded to 3 decimals, half away from zero.
  Decimal _toBase(Decimal quantity, FakeUnit unit) =>
      (quantity * unit.factor).round(scale: _quantityScale);

  bool _blank(String value) => FakeText.normalize(value).isEmpty;

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  FakeResponse _error(FakeRequest request, ApiErrorCode code) =>
      _problems.problem(request, FakeProblems.statusOf(code), code);

  static String _format(Decimal value, int scale) =>
      value.toStringAsFixed(scale);

  static String _timestamp(DateTime value) => value.toUtc().toIso8601String();

  Map<String, Object?> _listItemJson(FakeProduct product) {
    final base = product.baseUnit;
    return {
      'id': product.id,
      'name': product.name,
      'quantity': _format(product.quantity, _quantityScale),
      'baseUnit': {
        'id': base.id,
        'name': base.name,
        'sellPrice': _format(base.sellPrice, _moneyScale),
      },
      'lowStockThreshold': _format(product.lowStockThreshold, _quantityScale),
      'isLowStock': product.isLowStock,
      'isArchived': product.isArchived,
    };
  }

  Map<String, Object?> _detailJson(FakeProduct product) {
    final units = [...product.units]
      ..sort((a, b) {
        if (a.isBase != b.isBase) {
          return a.isBase ? -1 : 1;
        }
        return a.factor.compareTo(b.factor);
      });
    return {
      'id': product.id,
      'name': product.name,
      'barcode': product.barcode,
      'category': product.category,
      'quantity': _format(product.quantity, _quantityScale),
      'costPrice': _format(product.costPrice, _moneyScale),
      'lowStockThreshold': _format(product.lowStockThreshold, _quantityScale),
      'isLowStock': product.isLowStock,
      'isArchived': product.isArchived,
      'units': [for (final unit in units) _unitJson(unit)],
      'createdAt': _timestamp(product.createdAt),
      'updatedAt': _timestamp(product.updatedAt),
    };
  }

  Map<String, Object?> _unitJson(FakeUnit unit) => {
    'id': unit.id,
    'name': unit.name,
    'factor': _format(unit.factor, _factorScale),
    'sellPrice': _format(unit.sellPrice, _moneyScale),
    'barcode': unit.barcode,
    'isBase': unit.isBase,
  };

  Map<String, Object?> _movementJson(FakeMovement movement) => {
    'id': movement.id,
    'productId': movement.productId,
    'quantityChange': _format(movement.quantityChange, _quantityScale),
    'balanceAfter': _format(movement.balanceAfter, _quantityScale),
    'reason': movement.reason,
    'invoiceId': movement.invoiceId,
    'saleId': movement.saleId,
    'note': movement.note,
    'createdByUserId': movement.createdByUserId,
    'createdAt': _timestamp(movement.createdAt),
  };
}
