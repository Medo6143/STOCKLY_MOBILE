import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_input_rules.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';

import '../../../helpers/products_doubles.dart';

Map<ProductField, ProductFieldIssue> _issues<T>(ProductInput<T> input) =>
    (input as ProductInputInvalid<T>).issues;

T _value<T>(ProductInput<T> input) => (input as ProductInputValid<T>).value;

ProductInput<ProductDraft> _create({
  String name = 'بنادول اكسترا',
  String barcode = '',
  String category = '',
  String baseUnitName = 'شريط',
  String costPrice = '12.50',
  String sellPrice = '15',
  String threshold = '',
  String opening = '',
  bool includeOpening = true,
}) => ProductInputRules.create(
  name: name,
  barcode: barcode,
  category: category,
  baseUnitName: baseUnitName,
  costPrice: costPrice,
  baseUnitSellPrice: sellPrice,
  lowStockThreshold: threshold,
  openingQuantity: opening,
  includeOpening: includeOpening,
);

void main() {
  group('create (P3)', () {
    test('Create_Valid_TrimmedDraftWithExactDecimals', () {
      final draft = _value(
        _create(
          name: '  بنادول اكسترا ',
          barcode: ' 622 ',
          threshold: '٥',
          opening: '24.5',
        ),
      );

      expect(draft.name, 'بنادول اكسترا');
      expect(draft.barcode, '622');
      expect(draft.category, isNull);
      expect(draft.costPrice, money('12.50'));
      expect(draft.baseUnitSellPrice.toApi(), '15.00');
      expect(draft.lowStockThreshold, quantity('5.000'));
      expect(draft.openingQuantity, quantity('24.500'));
    });

    test('Create_OptionalNumbersEmpty_Null', () {
      final draft = _value(_create());

      expect(draft.lowStockThreshold, isNull);
      expect(draft.openingQuantity, isNull);
    });

    test('Create_StaffNeverSendsOpening', () {
      final draft = _value(_create(opening: '24', includeOpening: false));

      expect(draft.openingQuantity, isNull);
    });

    test('Create_EveryIssue_ReportedPerField', () {
      final issues = _issues(
        _create(
          name: ' ',
          baseUnitName: '',
          costPrice: '1.234',
          sellPrice: '-1',
          threshold: 'abc',
          opening: '123456789012',
          barcode: 'x' * 65,
          category: 'y' * 101,
        ),
      );

      expect(issues, {
        ProductField.name: ProductFieldIssue.required,
        ProductField.baseUnitName: ProductFieldIssue.required,
        ProductField.costPrice: ProductFieldIssue.tooManyDecimals,
        ProductField.baseUnitSellPrice: ProductFieldIssue.negative,
        ProductField.lowStockThreshold: ProductFieldIssue.invalidNumber,
        ProductField.openingQuantity: ProductFieldIssue.outOfRange,
        ProductField.barcode: ProductFieldIssue.tooLong,
        ProductField.category: ProductFieldIssue.tooLong,
      });
    });

    test('Create_RequiredPricesEmpty_Required', () {
      final issues = _issues(_create(costPrice: '', sellPrice: ''));

      expect(issues[ProductField.costPrice], ProductFieldIssue.required);
      expect(
        issues[ProductField.baseUnitSellPrice],
        ProductFieldIssue.required,
      );
    });
  });

  group('update (P4)', () {
    test('Update_Valid_ThresholdRequired', () {
      final update = _value(
        ProductInputRules.update(
          name: 'x',
          barcode: '',
          category: 'c',
          costPrice: '1',
          lowStockThreshold: '0',
        ),
      );
      final missing = _issues(
        ProductInputRules.update(
          name: 'x',
          barcode: '',
          category: '',
          costPrice: '1',
          lowStockThreshold: '',
        ),
      );

      expect(
        update,
        ProductUpdate(
          name: 'x',
          barcode: null,
          category: 'c',
          costPrice: money('1.00'),
          lowStockThreshold: quantity('0.000'),
        ),
      );
      expect(missing, {
        ProductField.lowStockThreshold: ProductFieldIssue.required,
      });
    });
  });

  group('unit (P6, P7)', () {
    test('Unit_Valid_FactorUpToSixDecimals', () {
      final unit = _value(
        ProductInputRules.unit(
          name: 'علبة',
          factor: '2.5',
          sellPrice: '40',
          barcode: '',
        ),
      );

      expect(unit.factor.toApi(), '2.500000');
      expect(unit.barcode, isNull);
      expect(unit, isA<UnitDraft>());
    });

    test('Unit_ZeroFactorAndTooManyDecimals_Issues', () {
      expect(
        _issues(
          ProductInputRules.unit(
            name: 'x',
            factor: '0',
            sellPrice: '1',
            barcode: '',
          ),
        ),
        {ProductField.unitFactor: ProductFieldIssue.notPositive},
      );
      expect(
        _issues(
          ProductInputRules.unit(
            name: '',
            factor: '1.0000001',
            sellPrice: '1',
            barcode: '',
          ),
        ),
        {
          ProductField.unitName: ProductFieldIssue.required,
          ProductField.unitFactor: ProductFieldIssue.tooManyDecimals,
        },
      );
    });
  });

  group('adjustment (P9)', () {
    test('Adjustment_NegativeArabicDigits_Valid', () {
      final draft = _value(
        ProductInputRules.adjustment(
          quantityChange: '-٢',
          unitId: boxUnitId,
          note: ' Expired ',
        ),
      );

      expect(
        draft,
        StockAdjustmentDraft(
          quantityChange: quantity('-2.000'),
          unitId: boxUnitId,
          note: 'Expired',
        ),
      );
    });

    test('Adjustment_ZeroAndBlankNote_Issues', () {
      expect(
        _issues(
          ProductInputRules.adjustment(
            quantityChange: '0.000',
            unitId: null,
            note: ' ',
          ),
        ),
        {
          ProductField.quantityChange: ProductFieldIssue.zero,
          ProductField.note: ProductFieldIssue.required,
        },
      );
      expect(
        _issues(
          ProductInputRules.adjustment(
            quantityChange: '1',
            unitId: null,
            note: 'n' * 501,
          ),
        ),
        {ProductField.note: ProductFieldIssue.tooLong},
      );
    });
  });

  group('count (P10)', () {
    test('Count_ZeroAllowed_NegativeRejected', () {
      expect(
        _value(ProductInputRules.count(countedQuantity: '0', unitId: null)),
        StockCountDraft(countedQuantity: quantity('0.000'), unitId: null),
      );
      expect(
        _issues(ProductInputRules.count(countedQuantity: '-1', unitId: null)),
        {ProductField.countedQuantity: ProductFieldIssue.negative},
      );
      expect(
        _issues(ProductInputRules.count(countedQuantity: '', unitId: null)),
        {ProductField.countedQuantity: ProductFieldIssue.required},
      );
    });
  });
}
