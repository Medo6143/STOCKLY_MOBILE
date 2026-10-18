import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';

import '../../../helpers/invoices_doubles.dart';

InvoiceLineInput _input({
  int lineNo = 4,
  String rawName = 'سيتال',
  LineChoiceInput choice = const LineChoiceInput.existing(
    productId: productId,
    productName: 'بنادول اكسترا',
    unitId: boxUnitId,
    unitName: 'علبة',
  ),
  String qty = '2',
  String price = '36',
  String batch = '',
}) => InvoiceLineInput(
  lineNo: lineNo,
  rawName: rawName,
  choice: choice,
  quantity: qty,
  unitPrice: price,
  batchNo: batch,
);

/// Design §11 "Invoice review rules".
void main() {
  group('InvoiceDraft.fromDetail', () {
    test('Choices_ExistingNewOrUnresolved', () {
      final draft = InvoiceDraft.fromDetail(invoiceDetail());

      expect(draft.lines.map((l) => l.lineNo), [1, 2, 3]);
      expect(
        draft.lines[0].choice,
        const LineProductChoice.existing(
          productId: productId,
          productUnitId: boxUnitId,
          productName: 'بنادول اكسترا',
          unitName: 'علبة',
        ),
      );
      expect(draft.lines[1].choice, const LineProductChoice.unresolved());
      expect(draft.lines[2].choice, LineProductChoice.newProduct(sitalNew));
      expect(draft.header.supplierName, 'شركة الأدوية المتحدة');
      expect(draft.header.totalAmount, money('1250.00'));
      expect(draft.lines.first.lineTotal, money('360.00'));
      expect(draft.unresolvedLineNos, [2]);
    });

    test('LinesSortedByLineNo', () {
      final draft = InvoiceDraft.fromDetail(
        invoiceDetail(items: [invoiceItem(lineNo: 3), invoiceItem()]),
      );

      expect(draft.lines.map((l) => l.lineNo), [1, 3]);
    });

    test('Editable_OnlyNeedsReview', () {
      expect(invoiceDetail().isEditable, isTrue);
      expect(
        invoiceDetail(status: InvoiceStatus.confirmed).isEditable,
        isFalse,
      );
    });
  });

  group('Draft lines', () {
    final draft = InvoiceDraft.fromDetail(invoiceDetail());

    test('NextLineNo_MaxPlusOne', () {
      expect(draft.nextLineNo, 4);
      expect(
        const InvoiceDraft(header: InvoiceHeaderDraft(), lines: []).nextLineNo,
        1,
      );
    });

    test('WithLine_ReplacesOrAppends', () {
      final edited = draft.lines.first.copyWith(rawName: 'x');
      final added = draft.lines.first.copyWith(lineNo: 9);

      expect(draft.withLine(edited).lines.first.rawName, 'x');
      expect(draft.withLine(edited).lines, hasLength(3));
      expect(draft.withLine(added).lines.last.lineNo, 9);
    });

    test('WithoutLine_Removes', () {
      expect(draft.withoutLine(2).lines.map((l) => l.lineNo), [1, 3]);
    });

    test('HundredLines_CannotAddMore', () {
      final full = InvoiceDraft(
        header: const InvoiceHeaderDraft(),
        lines: [
          for (var i = 1; i <= InvoiceRules.maxLines; i++)
            draft.lines.first.copyWith(lineNo: i),
        ],
      );

      expect(full.canAddLine, isFalse);
      expect(
        full.withLine(draft.lines.first.copyWith(lineNo: 101)).lines,
        hasLength(100),
      );
      expect(full.withoutLine(1).canAddLine, isTrue);
    });
  });

  group('InvoiceInputRules.line', () {
    test('Valid_ExistingProduct', () {
      final check = InvoiceInputRules.line(_input(batch: ' B1 '));

      final line = (check as InvoiceLineValid).line;
      expect(line.quantity, quantity('2.000'));
      expect(line.unitPrice, money('36.00'));
      expect(line.batchNo, 'B1');
      expect(line.lineTotal, isNull);
    });

    test('ArabicDigits_Accepted', () {
      final check = InvoiceInputRules.line(_input(qty: '١٫٥', price: '١٢'));

      expect((check as InvoiceLineValid).line.quantity, quantity('1.500'));
    });

    test('Unchanged_KeepsServerTotalAndConfidence', () {
      final previous = InvoiceDraft.fromDetail(invoiceDetail()).lines.first;

      final check = InvoiceInputRules.line(
        _input(lineNo: 1, qty: '10', price: '36.00'),
        previous: previous,
      );

      final line = (check as InvoiceLineValid).line;
      expect(line.lineTotal, money('360.00'));
      expect(line.matchConfidence, previous.matchConfidence);
    });

    test('ChangedQuantity_DropsTheServerTotal', () {
      final previous = InvoiceDraft.fromDetail(invoiceDetail()).lines.first;

      final check = InvoiceInputRules.line(
        _input(lineNo: 1, qty: '11'),
        previous: previous,
      );

      final line = (check as InvoiceLineValid).line;
      expect(line.lineTotal, isNull);
      expect(line.matchConfidence, previous.matchConfidence);
    });

    test('Issues_EveryField', () {
      final check = InvoiceInputRules.line(
        _input(
          rawName: ' ',
          qty: '0',
          price: '1.005',
          choice: const LineChoiceInput.none(),
        ),
      );

      expect((check as InvoiceLineInvalid).issues, {
        InvoiceLineField.rawName: InvoiceFieldIssue.required,
        InvoiceLineField.quantity: InvoiceFieldIssue.notPositive,
        InvoiceLineField.unitPrice: InvoiceFieldIssue.tooManyDecimals,
        InvoiceLineField.product: InvoiceFieldIssue.required,
      });
    });

    test('QuantityIssues', () {
      InvoiceFieldIssue? issueOf(String qty) => (InvoiceInputRules.line(
        _input(qty: qty),
      ) as InvoiceLineInvalid?)?.issues[InvoiceLineField.quantity];

      expect(issueOf(''), InvoiceFieldIssue.required);
      expect(issueOf('abc'), InvoiceFieldIssue.invalidNumber);
      expect(issueOf('1.0001'), InvoiceFieldIssue.tooManyDecimals);
      expect(issueOf('-1'), InvoiceFieldIssue.negative);
      expect(issueOf('123456789012345678'), InvoiceFieldIssue.outOfRange);
    });

    test('ExistingWithoutUnit_UnitRequired', () {
      final check = InvoiceInputRules.line(
        _input(
          choice: const LineChoiceInput.existing(
            productId: productId,
            productName: 'بنادول اكسترا',
          ),
        ),
      );

      expect((check as InvoiceLineInvalid).issues, {
        InvoiceLineField.unit: InvoiceFieldIssue.required,
      });
    });

    test('NewProduct_ValidAndInvalid', () {
      final valid = InvoiceInputRules.line(
        _input(
          choice: const LineChoiceInput.newProduct(
            name: ' سيتال شراب ',
            baseUnitName: 'زجاجة',
            sellPrice: '25',
          ),
        ),
      );
      final invalid = InvoiceInputRules.line(
        _input(
          choice: const LineChoiceInput.newProduct(
            name: '',
            baseUnitName: '',
            sellPrice: '-1',
          ),
        ),
      );

      expect(
        (valid as InvoiceLineValid).line.choice,
        LineProductChoice.newProduct(sitalNew),
      );
      expect((invalid as InvoiceLineInvalid).issues, {
        InvoiceLineField.newProductName: InvoiceFieldIssue.required,
        InvoiceLineField.newProductBaseUnitName: InvoiceFieldIssue.required,
        InvoiceLineField.newProductSellPrice: InvoiceFieldIssue.negative,
      });
    });

    test('ExpiryDate_Kept', () {
      final check = InvoiceInputRules.line(
        _input().copyWith(expiryDate: const CalendarDate(2027, 1, 31)),
      );

      expect(
        (check as InvoiceLineValid).line.expiryDate,
        const CalendarDate(2027, 1, 31),
      );
    });

    test('OptionalMoney_BlankIsNull', () {
      expect(InvoiceInputRules.optionalMoney(''), (value: null, issue: null));
      expect(InvoiceInputRules.optionalMoney('12.5').value, money('12.50'));
      expect(
        InvoiceInputRules.optionalMoney('x').issue,
        InvoiceFieldIssue.invalidNumber,
      );
    });
  });

  group('InvoiceLineMatchCheck', () {
    InvoiceLineDraft line({
      String? confidence,
      LineProductChoice choice = const LineProductChoice.existing(
        productId: productId,
        productUnitId: boxUnitId,
        productName: 'بنادول اكسترا',
        unitName: 'علبة',
      ),
    }) => InvoiceLineDraft(
      lineNo: 1,
      rawName: 'بنادول',
      choice: choice,
      quantity: Quantity.fromApi('1.000'),
      unitPrice: Money.fromApi('10.00'),
      matchConfidence: confidence == null
          ? null
          : MatchConfidence.fromApi(confidence),
    );

    test('Threshold_IsNinetyPercent', () {
      expect(InvoiceRules.matchCheckThreshold.toString(), '0.90');
    });

    test('BelowThreshold_NeedsCheck', () {
      expect(line(confidence: '0.89').needsMatchCheck, isTrue);
      expect(line(confidence: '0.40').needsMatchCheck, isTrue);
      expect(line(confidence: '0.00').needsMatchCheck, isTrue);
    });

    test('AtOrAboveThreshold_NoCheck', () {
      expect(line(confidence: '0.90').needsMatchCheck, isFalse);
      expect(line(confidence: '0.95').needsMatchCheck, isFalse);
      expect(line(confidence: '1.00').needsMatchCheck, isFalse);
    });

    test('NoConfidence_NoCheck', () {
      expect(line().needsMatchCheck, isFalse);
    });

    test('NotAnExistingProduct_NoCheck', () {
      expect(
        line(
          confidence: '0.40',
          choice: const LineProductChoice.unresolved(),
        ).needsMatchCheck,
        isFalse,
      );
    });
  });
}
