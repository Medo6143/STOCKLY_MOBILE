import 'package:decimal/decimal.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';

/// One extra unit of a seeded product.
final class _SeedUnit {
  const new(this.name, this.factor, this.sellPrice, {this.barcode});

  final String name;
  final String factor;
  final String sellPrice;
  final String? barcode;
}

/// One past movement of a seeded product (oldest first).
final class _SeedMove {
  const new(this.reason, this.change, {this.note, this.document});

  final String reason;
  final String change;
  final String? note;

  /// Marks a receipt or sale with a document id.
  final bool? document;
}

/// One seeded product: an [opening] stock count (none when zero), then
/// its [history]; the quantity is their sum.
final class _SeedProduct {
  const new({
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.cost,
    required this.sell,
    required this.threshold,
    required this.opening,
    this.history = const [],
    this.barcode,
    this.units = const [],
    this.archived = false,
  });

  final String name;
  final String category;
  final String baseUnit;
  final String cost;
  final String sell;
  final String threshold;
  final String opening;
  final List<_SeedMove> history;
  final String? barcode;
  final List<_SeedUnit> units;
  final bool archived;
}

/// The Arabic pharmacy catalogue of the fake backend (design §12.1): 31
/// products (one archived), several at or below their low-stock level,
/// one below zero, units with barcodes, and a movement behind every
/// quantity.
abstract final class FakeProductSeed {
  static const String _idPrefix = '0192f0a0-6c1e-7b3a-9d2e-';
  static const int _idDigits = 12;
  static const int _productKind = 0xa;
  static const int _unitKind = 0xb;
  static const int _movementKind = 0xc;
  static const int _documentKind = 0xd;
  static const int _kindShift = 40;
  static const Duration _historyStart = Duration(days: 30);
  static const Duration _step = Duration(days: 3);

  /// Barcode of the first product (also on its box unit, see [boxBarcode]).
  static const String panadolBarcode = '6221234567890';

  /// Barcode of the box unit of the first product.
  static const String boxBarcode = '6221234567906';

  static const List<_SeedProduct> _products = [
    _SeedProduct(
      name: 'بنادول اكسترا',
      opening: '12',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '12.50',
      sell: '15.00',
      threshold: '5',
      barcode: panadolBarcode,
      units: [_SeedUnit('علبة', '3', '40.00', barcode: boxBarcode)],
      history: [
        _SeedMove(FakeMovementReasons.invoiceReceipt, '18', document: true),
        _SeedMove(FakeMovementReasons.sale, '-6', document: true),
      ],
    ),
    _SeedProduct(
      name: 'بنادول أدفانس',
      opening: '10',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '10.00',
      sell: '12.50',
      threshold: '5',
      history: [_SeedMove(FakeMovementReasons.sale, '-7')],
    ),
    _SeedProduct(
      name: 'كونجستال',
      opening: '20',
      category: 'برد وإنفلونزا',
      baseUnit: 'شريط',
      cost: '14.00',
      sell: '17.00',
      threshold: '4',
      barcode: '6221025012345',
      units: [_SeedUnit('علبة', '2', '32.00')],
    ),
    _SeedProduct(
      name: 'أوجمنتين 1 جم',
      opening: '7',
      category: 'مضادات حيوية',
      baseUnit: 'شريط',
      cost: '52.00',
      sell: '62.00',
      threshold: '3',
      units: [_SeedUnit('علبة', '2', '120.00')],
    ),
    _SeedProduct(
      name: 'فلاجيل 500',
      opening: '12',
      category: 'مضادات حيوية',
      baseUnit: 'شريط',
      cost: '9.00',
      sell: '11.00',
      threshold: '5',
      history: [_SeedMove(FakeMovementReasons.sale, '-8')],
    ),
    _SeedProduct(
      name: 'أنتينال',
      opening: '30',
      category: 'معدة',
      baseUnit: 'شريط',
      cost: '13.00',
      sell: '16.00',
      threshold: '5',
    ),
    _SeedProduct(
      name: 'نوفالجين',
      opening: '2',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '6.50',
      sell: '8.00',
      threshold: '5',
      history: [_SeedMove(FakeMovementReasons.sale, '-5', document: true)],
    ),
    _SeedProduct(
      name: 'بروفين 400',
      opening: '15',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '11.00',
      sell: '14.00',
      threshold: '5',
    ),
    _SeedProduct(
      name: 'كتافلام 50',
      opening: '9',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '15.00',
      sell: '19.00',
      threshold: '5',
      history: [
        _SeedMove(
          FakeMovementReasons.manualAdjustment,
          '-1',
          note: 'شريط تالف',
        ),
      ],
    ),
    _SeedProduct(
      name: 'فيتامين سي 1000',
      opening: '6',
      category: 'فيتامينات',
      baseUnit: 'أنبوبة',
      cost: '38.00',
      sell: '45.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'سنترم',
      opening: '5',
      category: 'فيتامينات',
      baseUnit: 'علبة',
      cost: '210.00',
      sell: '245.00',
      threshold: '2',
      history: [_SeedMove(FakeMovementReasons.sale, '-3')],
    ),
    _SeedProduct(
      name: 'ديباكين كرونو 500',
      opening: '10',
      category: 'أعصاب',
      baseUnit: 'شريط',
      cost: '28.00',
      sell: '34.00',
      threshold: '3',
    ),
    _SeedProduct(
      name: 'جلوكوفاج 500',
      opening: '40',
      category: 'سكر',
      baseUnit: 'شريط',
      cost: '7.00',
      sell: '9.00',
      threshold: '6',
      units: [_SeedUnit('علبة', '5', '44.00', barcode: '6221000000501')],
    ),
    _SeedProduct(
      name: 'كونكور 5',
      opening: '10',
      category: 'ضغط',
      baseUnit: 'شريط',
      cost: '22.00',
      sell: '27.00',
      threshold: '4',
      history: [_SeedMove(FakeMovementReasons.sale, '-6')],
    ),
    _SeedProduct(
      name: 'نيكسيوم 40',
      opening: '8',
      category: 'معدة',
      baseUnit: 'شريط',
      cost: '45.00',
      sell: '55.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'ريفو',
      opening: '50',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '3.00',
      sell: '4.00',
      threshold: '10',
    ),
    _SeedProduct(
      name: 'أوتريفين بخاخ',
      opening: '5',
      category: 'برد وإنفلونزا',
      baseUnit: 'عبوة',
      cost: '28.00',
      sell: '35.00',
      threshold: '3',
    ),
    _SeedProduct(
      name: 'بيتادين محلول',
      opening: '6',
      category: 'مطهرات',
      baseUnit: 'زجاجة',
      cost: '25.00',
      sell: '32.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'كحول 70٪',
      opening: '5',
      category: 'مطهرات',
      baseUnit: 'لتر',
      cost: '30.00',
      sell: '40.00',
      threshold: '2',
      history: [_SeedMove(FakeMovementReasons.sale, '-1.250', document: true)],
    ),
    _SeedProduct(
      name: 'شاش معقم',
      opening: '120',
      category: 'مستلزمات',
      baseUnit: 'قطعة',
      cost: '2.50',
      sell: '3.50',
      threshold: '20',
      units: [_SeedUnit('علبة', '10', '32.00')],
    ),
    _SeedProduct(
      name: 'سرنجة 5 مل',
      opening: '100',
      category: 'مستلزمات',
      baseUnit: 'قطعة',
      cost: '1.50',
      sell: '2.00',
      threshold: '30',
      units: [_SeedUnit('علبة', '100', '180.00')],
      history: [_SeedMove(FakeMovementReasons.sale, '-75')],
    ),
    _SeedProduct(
      name: 'قطن طبي 100 جم',
      opening: '20',
      category: 'مستلزمات',
      baseUnit: 'لفة',
      cost: '12.00',
      sell: '15.00',
      threshold: '5',
    ),
    _SeedProduct(
      name: 'ميزان حرارة رقمي',
      opening: '3',
      category: 'أجهزة',
      baseUnit: 'قطعة',
      cost: '55.00',
      sell: '75.00',
      threshold: '1',
      barcode: '6901234567892',
    ),
    _SeedProduct(
      name: 'جهاز ضغط ديجيتال',
      opening: '2',
      category: 'أجهزة',
      baseUnit: 'قطعة',
      cost: '650.00',
      sell: '780.00',
      threshold: '1',
    ),
    _SeedProduct(
      name: 'كريم بيبانثين',
      opening: '0',
      category: 'جلدية',
      baseUnit: 'أنبوبة',
      cost: '48.00',
      sell: '58.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'شامبو جونسون للأطفال',
      opening: '9',
      category: 'عناية بالطفل',
      baseUnit: 'زجاجة',
      cost: '60.00',
      sell: '72.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'حفاضات بامبرز مقاس 4',
      opening: '4',
      category: 'عناية بالطفل',
      baseUnit: 'عبوة',
      cost: '260.00',
      sell: '299.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'لبن سيميلاك 1',
      opening: '6',
      category: 'عناية بالطفل',
      baseUnit: 'علبة',
      cost: '330.00',
      sell: '365.00',
      threshold: '2',
    ),
    _SeedProduct(
      name: 'ماء أكسجين',
      opening: '14',
      category: 'مطهرات',
      baseUnit: 'زجاجة',
      cost: '8.00',
      sell: '10.00',
      threshold: '3',
    ),
    _SeedProduct(
      name: 'محلول معالجة الجفاف',
      opening: '36',
      category: 'معدة',
      baseUnit: 'كيس',
      cost: '2.00',
      sell: '3.00',
      threshold: '10',
      units: [_SeedUnit('علبة', '10', '28.00')],
    ),
    _SeedProduct(
      name: 'فيفادول',
      opening: '12',
      category: 'مسكنات',
      baseUnit: 'شريط',
      cost: '5.00',
      sell: '6.50',
      threshold: '5',
      archived: true,
    ),
  ];

  /// Adds the catalogue to [state] for [shopId]; movements are by
  /// [userId], spread over the 30 days before [now].
  static void addTo(
    FakeBackendState state, {
    required String shopId,
    required String userId,
    required DateTime now,
  }) {
    var serial = 0;
    String id(int kind) {
      serial++;
      final value = (kind << _kindShift) + serial;
      return '$_idPrefix${value.toRadixString(16).padLeft(_idDigits, '0')}';
    }

    final start = now.subtract(_historyStart);
    for (final seed in _products) {
      final productId = id(_productKind);
      final product = FakeProduct(
        id: productId,
        shopId: shopId,
        name: seed.name,
        barcode: seed.barcode,
        category: seed.category,
        costPrice: Decimal.parse(seed.cost),
        lowStockThreshold: Decimal.parse(seed.threshold),
        units: [
          FakeUnit(
            id: id(_unitKind),
            name: seed.baseUnit,
            factor: Decimal.one,
            sellPrice: Decimal.parse(seed.sell),
            barcode: null,
            isBase: true,
          ),
          for (final unit in seed.units)
            FakeUnit(
              id: id(_unitKind),
              name: unit.name,
              factor: Decimal.parse(unit.factor),
              sellPrice: Decimal.parse(unit.sellPrice),
              barcode: unit.barcode,
              isBase: false,
            ),
        ],
        createdAt: start,
        isArchived: seed.archived,
      );
      state.products.add(product);
      var at = start;
      final moves = [
        if (Decimal.parse(seed.opening) > Decimal.zero)
          _SeedMove(
            FakeMovementReasons.stockCount,
            seed.opening,
            note: FakeMovementReasons.openingStockNote,
          ),
        ...seed.history,
      ];
      for (final move in moves) {
        final change = move.change;
        final document = move.document ?? false ? id(_documentKind) : null;
        state.recordMovement(
          product,
          id: id(_movementKind),
          change: Decimal.parse(change),
          reason: move.reason,
          userId: userId,
          at: at,
          note: move.note,
          invoiceId: move.reason == FakeMovementReasons.invoiceReceipt
              ? document
              : null,
          saleId: move.reason == FakeMovementReasons.sale ? document : null,
        );
        at = at.add(_step);
      }
    }
    // The box of the first product is on an invoice line: it cannot be
    // removed (`ProductUnit.InUse`).
    state.unitsInUse.add(state.products.first.units.last.id);
  }
}
