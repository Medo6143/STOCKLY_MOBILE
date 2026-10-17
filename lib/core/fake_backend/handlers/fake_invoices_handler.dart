import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_controls.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/fake_invoice_records.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/fake_text.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// Which signs a decimal request field accepts.
enum _Sign { nonNegative, positive }

/// A checked I4 line, before the product checks.
typedef _LineInput = ({
  int lineNo,
  String rawName,
  String? productId,
  String? productUnitId,
  ({String name, String baseUnitName, String sellPrice})? newProduct,
  String quantity,
  String unitPrice,
  String? expiryDate,
  String? batchNo,
});

/// Fake I1–I5 (contract §6): `clientRequestId` idempotency, image checks,
/// per-minute rate limit and daily quota with `Retry-After`, a simulated
/// `Processing` → `NeedsReview` (or `Failed`) transition on the fake
/// clock, matching against the shop's products, the I4 rules and the
/// idempotent confirm that receives the stock.
final class FakeInvoicesHandler implements FakeHandler {
  new({
    required this._state,
    required this._config,
    required this._controls,
    required this._clock,
    required this._uuid,
    required this._problems,
    required this._authenticate,
  });

  final FakeBackendState _state;
  final FakeBackendConfig _config;
  final FakeBackendControls _controls;
  final Clock _clock;
  final UuidGenerator _uuid;
  final FakeProblems _problems;
  final FakeAccessToken? Function(FakeRequest request) _authenticate;

  static const String _invoice = '${ApiPaths.invoices}/{id}';
  static const String _idParam = 'id';
  static const String _location = 'Location';

  static const Set<String> _imageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Contract I1: 8 MB.
  static const int _maxImageBytes = 8 * 1024 * 1024;
  static const int _maxLines = 100;
  static const int _supplierMax = 200;
  static const int _numberMax = 64;
  static const int _rawNameMax = 500;
  static const int _productNameMax = 200;
  static const int _unitNameMax = 100;
  static const int _batchMax = 64;
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;
  static const int _moneyScale = 2;
  static const int _quantityScale = 3;
  static final Decimal _moneyLimit = Decimal.parse('10000000000000000');
  static final Decimal _quantityLimit = Decimal.parse('100000000000');

  /// Contract rule 16 (backend): more than 2% off is `TotalMismatch`.
  static final Decimal _mismatchShare = Decimal.parse('0.02');
  static const String _matchConfidence = '0.92';

  static final RegExp _decimal = RegExp(r'^-?[0-9]{1,17}(\.[0-9]+)?$');
  static final RegExp _uuidPattern = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Accepted scans per shop, for the rate limit and the daily quota.
  final Map<String, List<DateTime>> _accepted = {};
  int _scanCount = 0;

  @override
  List<FakeRoute> get routes => [
    FakeRoute('POST', ApiPaths.invoicesScan, (r) => _guard(r, _scan)),
    FakeRoute('GET', ApiPaths.invoices, (r) => _guard(r, _list)),
    FakeRoute('GET', _invoice, (r) => _guard(r, _get)),
    FakeRoute('PUT', '$_invoice/items', (r) => _guard(r, _updateItems)),
    FakeRoute('POST', '$_invoice/confirm', (r) => _guardAccess(r, _confirm)),
  ];

  /// `401` without a valid token, `403 Shop.Suspended`. The shop comes
  /// from the token only.
  FakeResponse _guard(
    FakeRequest request,
    FakeResponse Function(FakeRequest request, String shopId) handle,
  ) => _guardAccess(request, (r, access) => handle(r, access.shopId));

  /// [_guard] for handlers that also need the caller.
  FakeResponse _guardAccess(
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

  /// Applies every finished fake extraction of [shopId] (the dashboard
  /// counts the invoices awaiting review).
  void settleShop(String shopId) {
    for (final invoice in _state.invoices) {
      if (invoice.shopId == shopId) {
        _settle(invoice);
      }
    }
  }

  // I1
  FakeResponse _scan(FakeRequest request, String shopId) {
    final form = request.form;
    final clientRequestId = form?.fields['clientRequestId'];
    if (clientRequestId == null || !_uuidPattern.hasMatch(clientRequestId)) {
      return _problems.validation(request, {
        'clientRequestId': [
          if (clientRequestId == null)
            FakeMessages.required(request.language)
          else
            FakeMessages.invalidValue(request.language),
        ],
      });
    }
    final repeat = _byClientRequestId(shopId, clientRequestId.toLowerCase());
    if (repeat != null) {
      return FakeResponse.json(HttpStatus.ok, _listItemJson(_settle(repeat)));
    }
    final image = form?.files['image'];
    if (image == null || image.length == 0) {
      return _error(request, ApiErrorCode.invoiceImageRequired);
    }
    if (!_imageTypes.contains(image.contentType)) {
      return _error(request, ApiErrorCode.invoiceUnsupportedImageType);
    }
    if (image.length > _maxImageBytes) {
      return _error(request, ApiErrorCode.invoiceImageTooLarge);
    }
    final now = _clock.now();
    final accepted = _accepted.putIfAbsent(shopId, () => []);
    final recent = accepted
        .where((at) => now.difference(at) < _config.scanRateWindow)
        .toList();
    if (recent.length >= _config.scanRateLimit) {
      return _problems.problem(
        request,
        HttpStatus.tooManyRequests,
        ApiErrorCode.scanRateLimited,
        retryAfter: recent.first.add(_config.scanRateWindow).difference(now),
      );
    }
    final today = FakeCairoTime.dayOf(now);
    final usedToday = accepted
        .where((at) => FakeCairoTime.dayOf(at) == today)
        .length;
    final quota = _controls.scanQuotaExhausted ? 0 : _config.scanDailyQuota;
    if (usedToday >= quota) {
      return _problems.problem(
        request,
        HttpStatus.tooManyRequests,
        ApiErrorCode.scanDailyQuotaExceeded,
        retryAfter: FakeCairoTime.nextMidnight(now).difference(now),
      );
    }
    accepted.add(now);
    final extraction = FakeInvoiceSeed
        .extractions[_scanCount++ % FakeInvoiceSeed.extractions.length];
    final invoice = FakeInvoice(
      id: _uuid.v4(),
      shopId: shopId,
      clientRequestId: clientRequestId.toLowerCase(),
      status: FakeInvoiceStatuses.processing,
      createdAt: now,
      readyAt: now.add(_config.processingDelay),
      pending: extraction,
      language: request.language,
    );
    _state.invoices.add(invoice);
    return FakeResponse(
      HttpStatus.accepted,
      json: _listItemJson(invoice),
      headers: {_location: '${ApiPaths.invoices}/${invoice.id}'},
    );
  }

  // I2
  FakeResponse _list(FakeRequest request, String shopId) {
    final errors = <String, List<String>>{};
    final status = request.query[ApiQuery.status];
    if (status != null && !FakeInvoiceStatuses.all.contains(status)) {
      errors[ApiQuery.status] = [FakeMessages.invalidValue(request.language)];
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
        _state.invoices
            .where((i) => i.shopId == shopId)
            .map(_settle)
            .where((i) => status == null || i.status == status)
            .toList()
          ..sort((a, b) {
            final byDate = b.createdAt.compareTo(a.createdAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    return FakeResponse.json(HttpStatus.ok, {
      'items': [
        for (final row in rows.skip((page - 1) * pageSize).take(pageSize))
          _listItemJson(row),
      ],
      'page': page,
      'pageSize': pageSize,
      'totalCount': rows.length,
    });
  }

  // I3
  FakeResponse _get(FakeRequest request, String shopId) {
    final invoice = _invoiceOf(request, shopId);
    return invoice == null
        ? _error(request, ApiErrorCode.invoiceNotFound)
        : FakeResponse.json(HttpStatus.ok, _detailJson(invoice));
  }

  // I4
  FakeResponse _updateItems(FakeRequest request, String shopId) {
    final json = request.jsonObject ?? const <String, Object?>{};
    final language = request.language;
    final errors = <String, List<String>>{};
    void invalid(String field) =>
        errors[field] = [FakeMessages.invalidValue(language)];

    final supplierName = _optionalString(json, 'supplierName', _supplierMax);
    final invoiceNumber = _optionalString(json, 'invoiceNumber', _numberMax);
    final invoiceDate = _optionalDate(json, 'invoiceDate');
    final totalAmount = _optionalDecimal(json, 'totalAmount');
    for (final (field, value) in [
      ('supplierName', supplierName),
      ('invoiceNumber', invoiceNumber),
      ('invoiceDate', invoiceDate),
      ('totalAmount', totalAmount),
    ]) {
      if (value == _Field.invalid) {
        invalid(field);
      }
    }
    final rawItems = json['items'];
    final lines = <_LineInput>[];
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
      final seen = <int>{};
      for (var i = 0; i < rawItems.length; i++) {
        final line = _line(rawItems[i], 'items[$i]', errors, language, seen);
        if (line != null) {
          lines.add(line);
        }
      }
    }
    if (errors.isNotEmpty) {
      return _problems.validation(request, errors);
    }
    for (final code in [
      if (totalAmount case final String total)
        _precision(total, _moneyScale, _Sign.nonNegative, _moneyLimit),
      for (final line in lines) ...[
        _precision(
          line.quantity,
          _quantityScale,
          _Sign.positive,
          _quantityLimit,
        ),
        _precision(line.unitPrice, _moneyScale, _Sign.nonNegative, _moneyLimit),
        if (line.newProduct case final product?)
          _precision(
            product.sellPrice,
            _moneyScale,
            _Sign.nonNegative,
            _moneyLimit,
          ),
      ],
    ]) {
      if (code != null) {
        return _error(request, code);
      }
    }
    final invoice = _invoiceOf(request, shopId);
    if (invoice == null) {
      return _error(request, ApiErrorCode.invoiceNotFound);
    }
    if (invoice.status != FakeInvoiceStatuses.needsReview) {
      return _error(request, ApiErrorCode.invoiceNotEditable);
    }
    for (final line in lines) {
      final code = _productError(shopId, line);
      if (code != null) {
        return _error(request, code);
      }
    }
    final previous = {for (final item in invoice.items) item.lineNo: item};
    invoice
      ..supplierName = supplierName is String ? supplierName.trim() : null
      ..invoiceNumber = invoiceNumber is String ? invoiceNumber.trim() : null
      ..invoiceDate = invoiceDate is String ? invoiceDate : null
      ..totalAmount = totalAmount is String ? Decimal.parse(totalAmount) : null
      ..items = [for (final line in lines) _item(line, previous[line.lineNo])]
      ..warnings = [
        ...invoice.warnings.where(FakeInvoiceWarnings.extractionOnly.contains),
      ];
    _recomputeWarnings(invoice);
    return FakeResponse.json(HttpStatus.ok, _detailJson(invoice));
  }

  // I5
  FakeResponse _confirm(FakeRequest request, FakeAccessToken access) {
    final invoice = _invoiceOf(request, access.shopId);
    if (invoice == null) {
      return _error(request, ApiErrorCode.invoiceNotFound);
    }
    if (invoice.status == FakeInvoiceStatuses.confirmed) {
      return FakeResponse.json(HttpStatus.ok, _detailJson(invoice));
    }
    if (invoice.status != FakeInvoiceStatuses.needsReview) {
      return _error(request, ApiErrorCode.invoiceNotConfirmable);
    }
    if (invoice.items.any((i) => i.productId == null && i.newProduct == null)) {
      return _error(request, ApiErrorCode.invoiceLineProductRequired);
    }
    final now = _clock.now();
    final lines = [...invoice.items]
      ..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    invoice
      ..items = [
        for (final line in lines) _receive(invoice, line, access.userId, now),
      ]
      ..status = FakeInvoiceStatuses.confirmed
      ..confirmedAt = now;
    return FakeResponse.json(HttpStatus.ok, _detailJson(invoice));
  }

  /// Receives one confirmed line in base units, creating its new product
  /// first. A new product's line then names the created product (contract
  /// §6 `InvoiceItemDto`, `newProduct` is kept).
  FakeInvoiceItem _receive(
    FakeInvoice invoice,
    FakeInvoiceItem line,
    String userId,
    DateTime now,
  ) {
    final existing = _state.productOf(invoice.shopId, line.productId);
    final product = existing ?? _createProduct(invoice.shopId, line, now);
    final unit = product.unitById(line.productUnitId) ?? product.baseUnit;
    _state
      ..recordMovement(
        product,
        id: _uuid.v4(),
        change: (line.quantity * unit.factor).round(scale: _quantityScale),
        reason: FakeMovementReasons.invoiceReceipt,
        userId: userId,
        at: now,
        invoiceId: invoice.id,
      )
      ..unitsInUse.add(unit.id);
    return FakeInvoiceItem(
      id: line.id,
      lineNo: line.lineNo,
      rawName: line.rawName,
      productId: product.id,
      productUnitId: unit.id,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      lineTotal: line.lineTotal,
      expiryDate: line.expiryDate,
      batchNo: line.batchNo,
      matchConfidence: line.matchConfidence,
      newProduct: line.newProduct,
    );
  }

  /// The product a `newProduct` line asks for: cost = the line's price,
  /// one base unit, stock from the receipt only.
  FakeProduct _createProduct(
    String shopId,
    FakeInvoiceItem line,
    DateTime now,
  ) {
    final wanted = line.newProduct!;
    final product = FakeProduct(
      id: _uuid.v4(),
      shopId: shopId,
      name: wanted.name,
      barcode: null,
      category: null,
      costPrice: line.unitPrice,
      lowStockThreshold: Decimal.zero,
      units: [
        FakeUnit(
          id: _uuid.v4(),
          name: wanted.baseUnitName,
          factor: Decimal.one,
          sellPrice: wanted.sellPrice,
          barcode: null,
          isBase: true,
        ),
      ],
      createdAt: now,
    );
    _state.products.add(product);
    return product;
  }

  /// The shape checks of one I4 line; `null` when it has errors.
  _LineInput? _line(
    Object? raw,
    String path,
    Map<String, List<String>> errors,
    String language,
    Set<int> seen,
  ) {
    void invalid(String field) =>
        errors['$path.$field'] = [FakeMessages.invalidValue(language)];
    void required(String field) =>
        errors['$path.$field'] = [FakeMessages.required(language)];
    if (raw is! Map<String, Object?>) {
      errors[path] = [FakeMessages.invalidValue(language)];
      return null;
    }
    final before = errors.length;
    final lineNo = raw['lineNo'];
    if (lineNo is! int || lineNo < 1 || !seen.add(lineNo)) {
      invalid('lineNo');
    }
    final rawName = raw['rawName'];
    if (rawName is! String || rawName.trim().isEmpty) {
      required('rawName');
    } else if (rawName.length > _rawNameMax) {
      errors['$path.rawName'] = [FakeMessages.tooLong(language, _rawNameMax)];
    }
    final productId = raw['productId'];
    final unitId = raw['productUnitId'];
    if (productId != null &&
        (productId is! String || !_uuidPattern.hasMatch(productId))) {
      invalid('productId');
    }
    if (unitId != null &&
        (unitId is! String || !_uuidPattern.hasMatch(unitId))) {
      invalid('productUnitId');
    }
    if ((productId == null) != (unitId == null)) {
      required(productId == null ? 'productId' : 'productUnitId');
    }
    final newProduct = _newProduct(
      raw['newProduct'],
      '$path.newProduct',
      errors,
      language,
    );
    if (productId != null && raw['newProduct'] != null) {
      invalid('newProduct');
    }
    final quantity = raw['quantity'];
    if (quantity is! String || !_decimal.hasMatch(quantity)) {
      errors['$path.quantity'] = [FakeMessages.decimalFormat(language)];
    }
    final unitPrice = raw['unitPrice'];
    if (unitPrice is! String || !_decimal.hasMatch(unitPrice)) {
      errors['$path.unitPrice'] = [FakeMessages.decimalFormat(language)];
    }
    final expiry = _optionalDate(raw, 'expiryDate');
    if (expiry == _Field.invalid) {
      invalid('expiryDate');
    }
    final batch = _optionalString(raw, 'batchNo', _batchMax);
    if (batch == _Field.invalid) {
      invalid('batchNo');
    }
    if (errors.length != before) {
      return null;
    }
    return (
      lineNo: lineNo! as int,
      rawName: (rawName! as String).trim(),
      productId: (productId as String?)?.toLowerCase(),
      productUnitId: (unitId as String?)?.toLowerCase(),
      newProduct: newProduct,
      quantity: quantity! as String,
      unitPrice: unitPrice! as String,
      expiryDate: expiry is String ? expiry : null,
      batchNo: batch is String && batch.trim().isNotEmpty ? batch.trim() : null,
    );
  }

  ({String name, String baseUnitName, String sellPrice})? _newProduct(
    Object? raw,
    String path,
    Map<String, List<String>> errors,
    String language,
  ) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      errors[path] = [FakeMessages.invalidValue(language)];
      return null;
    }
    final name = raw['name'];
    final unit = raw['baseUnitName'];
    final price = raw['sellPrice'];
    if (name is! String || name.trim().isEmpty) {
      errors['$path.name'] = [FakeMessages.required(language)];
    } else if (name.length > _productNameMax) {
      errors['$path.name'] = [FakeMessages.tooLong(language, _productNameMax)];
    }
    if (unit is! String || unit.trim().isEmpty) {
      errors['$path.baseUnitName'] = [FakeMessages.required(language)];
    } else if (unit.length > _unitNameMax) {
      errors['$path.baseUnitName'] = [
        FakeMessages.tooLong(language, _unitNameMax),
      ];
    }
    if (price is! String || !_decimal.hasMatch(price)) {
      errors['$path.sellPrice'] = [FakeMessages.decimalFormat(language)];
    }
    return name is String && unit is String && price is String
        ? (name: name.trim(), baseUnitName: unit.trim(), sellPrice: price)
        : null;
  }

  /// The domain checks of one line, in the backend's order: a product is
  /// required, it must exist, and the unit must be one of its units.
  ApiErrorCode? _productError(String shopId, _LineInput line) {
    final productId = line.productId;
    if (productId == null) {
      return line.newProduct == null
          ? ApiErrorCode.invoiceLineProductRequired
          : null;
    }
    final product = _state.productOf(shopId, productId);
    if (product == null) {
      return ApiErrorCode.productNotFound;
    }
    if (product.unitById(line.productUnitId) != null) {
      return null;
    }
    final elsewhere = _state.products
        .where((p) => p.shopId == shopId)
        .any((p) => p.unitById(line.productUnitId) != null);
    return elsewhere
        ? ApiErrorCode.invoiceUnitNotOfProduct
        : ApiErrorCode.productUnitNotFound;
  }

  FakeInvoiceItem _item(_LineInput line, FakeInvoiceItem? previous) {
    final quantity = Decimal.parse(line.quantity);
    final unitPrice = Decimal.parse(line.unitPrice);
    final newProduct = line.newProduct;
    final sameProduct =
        previous != null &&
        previous.productId == line.productId &&
        previous.productUnitId == line.productUnitId;
    return FakeInvoiceItem(
      id: previous?.id ?? _uuid.v4(),
      lineNo: line.lineNo,
      rawName: line.rawName,
      productId: line.productId,
      productUnitId: line.productUnitId,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotalOf(quantity, unitPrice),
      expiryDate: line.expiryDate,
      batchNo: line.batchNo,
      matchConfidence: sameProduct && line.productId != null
          ? previous.matchConfidence
          : null,
      newProduct: newProduct == null
          ? null
          : FakeNewProduct(
              name: newProduct.name,
              baseUnitName: newProduct.baseUnitName,
              sellPrice: Decimal.parse(newProduct.sellPrice),
            ),
    );
  }

  /// `quantity × unitPrice`, rounded to 2 decimals away from zero.
  static Decimal lineTotalOf(Decimal quantity, Decimal unitPrice) =>
      (quantity * unitPrice).round(scale: _moneyScale);

  /// Applies the fake AI result once the fake clock passed `readyAt`.
  FakeInvoice _settle(FakeInvoice invoice) {
    final readyAt = invoice.readyAt;
    final extraction = invoice.pending;
    if (invoice.status != FakeInvoiceStatuses.processing ||
        readyAt == null ||
        extraction == null ||
        _clock.now().isBefore(readyAt)) {
      return invoice;
    }
    invoice
      ..pending = null
      ..processedAt = readyAt;
    if (extraction.fails) {
      invoice
        ..status = FakeInvoiceStatuses.failed
        ..failureReason = invoice.language == FakeMessages.arabic
            ? extraction.failureReasonAr
            : extraction.failureReasonEn;
      return invoice;
    }
    final total = extraction.totalAmount;
    invoice
      ..status = FakeInvoiceStatuses.needsReview
      ..supplierName = extraction.supplierName
      ..invoiceNumber = extraction.invoiceNumber
      ..invoiceDate = extraction.invoiceDate
      ..totalAmount = total == null ? null : Decimal.parse(total)
      ..warnings = [...extraction.warnings]
      ..items = [
        for (final (index, line) in extraction.lines.indexed)
          _extracted(invoice.shopId, index + 1, line),
      ];
    _recomputeWarnings(invoice);
    return invoice;
  }

  /// A line as the AI reads it, matched against the shop's products: the
  /// longest product name inside the raw name wins, with the unit named in
  /// the raw name or the base unit.
  FakeInvoiceItem _extracted(
    String shopId,
    int lineNo,
    FakeExtractedLine line,
  ) {
    final raw = FakeText.normalize(line.rawName);
    FakeProduct? match;
    for (final product in _state.products) {
      final name = FakeText.normalize(product.name);
      if (product.shopId == shopId &&
          !product.isArchived &&
          raw.contains(name) &&
          (match == null ||
              name.length > FakeText.normalize(match.name).length)) {
        match = product;
      }
    }
    final unit = match?.units.firstWhere(
      (u) => !u.isBase && raw.contains(FakeText.normalize(u.name)),
      orElse: () => match!.baseUnit,
    );
    final quantity = Decimal.parse(line.quantity);
    final unitPrice = Decimal.parse(line.unitPrice);
    return FakeInvoiceItem(
      id: _uuid.v4(),
      lineNo: lineNo,
      rawName: line.rawName,
      productId: match?.id,
      productUnitId: unit?.id,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotalOf(quantity, unitPrice),
      expiryDate: line.expiryDate,
      batchNo: line.batchNo,
      matchConfidence: match == null ? null : _matchConfidence,
      newProduct: null,
    );
  }

  /// `TotalMismatch` (more than 2% off) and `DuplicateInvoiceNumber`
  /// (another invoice of the shop has the same number).
  void _recomputeWarnings(FakeInvoice invoice) {
    final warnings = invoice.warnings
      ..remove(FakeInvoiceWarnings.totalMismatch)
      ..remove(FakeInvoiceWarnings.duplicateInvoiceNumber);
    final total = invoice.totalAmount;
    if (total != null && total > Decimal.zero) {
      final sum = invoice.items.fold(
        Decimal.zero,
        (sum, item) => sum + item.lineTotal,
      );
      if ((sum - total).abs() > total * _mismatchShare) {
        warnings.add(FakeInvoiceWarnings.totalMismatch);
      }
    }
    final number = invoice.invoiceNumber;
    if (number != null &&
        _state.invoices.any(
          (other) =>
              other.id != invoice.id &&
              other.shopId == invoice.shopId &&
              other.invoiceNumber == number,
        )) {
      warnings.add(FakeInvoiceWarnings.duplicateInvoiceNumber);
    }
  }

  FakeInvoice? _invoiceOf(FakeRequest request, String shopId) {
    final id = request.params[_idParam];
    for (final invoice in _state.invoices) {
      if (invoice.id == id && invoice.shopId == shopId) {
        return _settle(invoice);
      }
    }
    return null;
  }

  FakeInvoice? _byClientRequestId(String shopId, String clientRequestId) {
    for (final invoice in _state.invoices) {
      if (invoice.shopId == shopId &&
          invoice.clientRequestId == clientRequestId) {
        return invoice;
      }
    }
    return null;
  }

  /// The backend's `DecimalInput` order: sign, decimals (never rounded),
  /// then the column range.
  ApiErrorCode? _precision(
    String text,
    int maxDecimals,
    _Sign sign,
    Decimal limit,
  ) {
    final value = Decimal.parse(text);
    if (value < Decimal.zero) {
      return ApiErrorCode.precisionNegative;
    }
    if (sign == _Sign.positive && value == Decimal.zero) {
      return ApiErrorCode.precisionNotPositive;
    }
    if (value.scale > maxDecimals) {
      return ApiErrorCode.precisionTooManyDecimals;
    }
    return value.abs() < limit ? null : ApiErrorCode.precisionOutOfRange;
  }

  /// A string field: `null` when absent, the value, or [_Field.invalid].
  Object? _optionalString(Map<String, Object?> json, String field, int max) {
    final value = json[field];
    if (value == null) {
      return null;
    }
    return value is String && value.length <= max ? value : _Field.invalid;
  }

  Object? _optionalDate(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String || !_date.hasMatch(value)) {
      return _Field.invalid;
    }
    final parsed = DateTime.tryParse(value);
    return parsed == null || parsed.toIso8601String().substring(0, 10) != value
        ? _Field.invalid
        : value;
  }

  Object? _optionalDecimal(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) {
      return null;
    }
    return value is String && _decimal.hasMatch(value) ? value : _Field.invalid;
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

  static String? _formatOrNull(Decimal? value, int scale) =>
      value == null ? null : _format(value, scale);

  static String _timestamp(DateTime value) => value.toUtc().toIso8601String();

  Map<String, Object?> _listItemJson(FakeInvoice invoice) => {
    'id': invoice.id,
    'status': invoice.status,
    'supplierName': invoice.supplierName,
    'invoiceNumber': invoice.invoiceNumber,
    'invoiceDate': invoice.invoiceDate,
    'totalAmount': _formatOrNull(invoice.totalAmount, _moneyScale),
    'itemCount': invoice.items.length,
    'warnings': [...invoice.warnings],
    'createdAt': _timestamp(invoice.createdAt),
  };

  Map<String, Object?> _detailJson(FakeInvoice invoice) {
    final items = [...invoice.items]
      ..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    final processedAt = invoice.processedAt;
    final confirmedAt = invoice.confirmedAt;
    return {
      'id': invoice.id,
      'clientRequestId': invoice.clientRequestId,
      'status': invoice.status,
      'supplierId': null,
      'supplierName': invoice.supplierName,
      'invoiceNumber': invoice.invoiceNumber,
      'invoiceDate': invoice.invoiceDate,
      'totalAmount': _formatOrNull(invoice.totalAmount, _moneyScale),
      'computedTotal': items.isEmpty
          ? null
          : _format(
              items.fold(Decimal.zero, (sum, item) => sum + item.lineTotal),
              _moneyScale,
            ),
      'warnings': [...invoice.warnings],
      'failureReason': invoice.failureReason,
      'items': [for (final item in items) _itemJson(invoice.shopId, item)],
      'createdAt': _timestamp(invoice.createdAt),
      'processedAt': processedAt == null ? null : _timestamp(processedAt),
      'confirmedAt': confirmedAt == null ? null : _timestamp(confirmedAt),
    };
  }

  Map<String, Object?> _itemJson(String shopId, FakeInvoiceItem item) {
    final product = _state.productOf(shopId, item.productId);
    final unit = product?.unitById(item.productUnitId);
    final newProduct = item.newProduct;
    return {
      'id': item.id,
      'lineNo': item.lineNo,
      'rawName': item.rawName,
      'productId': item.productId,
      'productName': product?.name,
      'productUnitId': item.productUnitId,
      'unitName': unit?.name,
      'quantity': _format(item.quantity, _quantityScale),
      'unitPrice': _format(item.unitPrice, _moneyScale),
      'lineTotal': _format(item.lineTotal, _moneyScale),
      'expiryDate': item.expiryDate,
      'batchNo': item.batchNo,
      'matchConfidence': item.matchConfidence,
      'newProduct': newProduct == null
          ? null
          : {
              'name': newProduct.name,
              'baseUnitName': newProduct.baseUnitName,
              'sellPrice': _format(newProduct.sellPrice, _moneyScale),
            },
    };
  }
}

/// Marks a request field that is present but not valid.
enum _Field { invalid }

/// Africa/Cairo time for the daily quota (contract I1 v1.3): UTC+2, and
/// UTC+3 from the last Friday of April to the last Thursday of October
/// (Egypt's daylight saving time since 2023).
abstract final class FakeCairoTime {
  static const Duration _standard = Duration(hours: 2);
  static const Duration _summer = Duration(hours: 3);
  static const int _april = 4;
  static const int _october = 10;
  static const Duration _day = Duration(days: 1);

  static Duration offsetAt(DateTime utc) {
    final year = utc.toUtc().year;
    // Summer time starts at 00:00 local standard time on the last Friday
    // of April and ends at 24:00 local summer time on the last Thursday of
    // October (that is 00:00 on the following Friday).
    final start = _lastWeekday(
      year,
      _april,
      DateTime.friday,
    ).subtract(_standard);
    final end = _lastWeekday(year, _october, DateTime.friday).subtract(_summer);
    final moment = utc.toUtc();
    return !moment.isBefore(start) && moment.isBefore(end)
        ? _summer
        : _standard;
  }

  /// The Cairo calendar day of [utc], as `yyyy-MM-dd`.
  static String dayOf(DateTime utc) {
    final local = utc.toUtc().add(offsetAt(utc));
    return local.toIso8601String().substring(0, 10);
  }

  /// The next Cairo midnight after [utc], in UTC.
  static DateTime nextMidnight(DateTime utc) {
    final local = utc.toUtc().add(offsetAt(utc));
    final midnight = DateTime.utc(local.year, local.month, local.day + 1);
    return midnight.subtract(offsetAt(midnight.subtract(_standard)));
  }

  /// 00:00 UTC of the last [weekday] of [month] in [year].
  static DateTime _lastWeekday(int year, int month, int weekday) {
    var day = DateTime.utc(year, month + 1, 0);
    while (day.weekday != weekday) {
      day = day.subtract(_day);
    }
    return day;
  }
}
