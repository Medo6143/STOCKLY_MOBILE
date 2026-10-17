import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_line_editor_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// The line being edited: the invoice and the line number. A line number
/// that is not in the draft yet is a new line.
typedef InvoiceLineKey = ({String invoiceId, int lineNo});

/// Edits one line of the review draft in memory (design §11): nothing is
/// sent until the review is saved. The unit picker only offers units of
/// the chosen product, so `Invoice.UnitNotOfProduct` cannot happen.
final class InvoiceLineEditorNotifier extends Notifier<InvoiceLineEditorState> {
  new(this.key);

  final InvoiceLineKey key;

  @override
  InvoiceLineEditorState build() {
    final line = _line;
    switch (line?.choice) {
      case ExistingProductChoice(
        :final productId,
        :final productName,
        :final productUnitId,
      ):
        unawaited(Future.microtask(() => _loadUnits(productId)));
        return InvoiceLineEditorState(
          mode: LineProductMode.existing,
          productId: productId,
          productName: productName,
          unitId: productUnitId,
          unitsLoading: true,
        );
      case NewProductChoice():
        return const InvoiceLineEditorState(mode: LineProductMode.newProduct);
      case UnresolvedChoice() || null:
        return const InvoiceLineEditorState();
    }
  }

  InvoiceLineDraft? get _line => ref
      .read(invoiceReviewProvider(key.invoiceId))
      .value
      ?.draft
      .lineByNo(key.lineNo);

  /// A product from the picker: its base unit is chosen until the user
  /// picks another unit.
  void chooseProduct({required String productId, required String name}) {
    state = InvoiceLineEditorState(
      mode: LineProductMode.existing,
      productId: productId,
      productName: name,
      unitsLoading: true,
    );
    unawaited(_loadUnits(productId));
  }

  void chooseUnit(String unitId) => state = state.copyWith(
    unitId: unitId,
    issues: {...state.issues}..remove(InvoiceLineField.unit),
  );

  /// The line will create a new product on confirm.
  void chooseNewProduct() => state = InvoiceLineEditorState(
    mode: LineProductMode.newProduct,
    issues: {...state.issues}..remove(InvoiceLineField.product),
  );

  /// Loads the units of the chosen product again after a failure.
  void retryUnits() {
    final productId = state.productId;
    if (productId != null) {
      state = state.copyWith(unitsLoading: true, unitsFailure: null);
      unawaited(_loadUnits(productId));
    }
  }

  Future<void> _loadUnits(String productId) async {
    final result = await ref.read(getProductUseCaseProvider).call(productId);
    if (!ref.mounted || state.productId != productId) {
      return;
    }
    switch (result) {
      case Ok(value: final product):
        state = state.copyWith(
          units: product.units,
          unitsLoading: false,
          unitId: state.unitId ?? product.baseUnit.id,
        );
      case Err(:final failure):
        state = state.copyWith(unitsLoading: false, unitsFailure: failure);
    }
  }

  /// Checks the typed fields and, when they are valid, puts the line into
  /// the review draft.
  void save({
    required String rawName,
    required String quantity,
    required String unitPrice,
    required String batchNo,
    required CalendarDate? expiryDate,
    required String newProductName,
    required String newProductBaseUnitName,
    required String newProductSellPrice,
  }) {
    final check = InvoiceInputRules.line(
      InvoiceLineInput(
        lineNo: key.lineNo,
        rawName: rawName,
        choice: _choiceInput(
          newProductName: newProductName,
          newProductBaseUnitName: newProductBaseUnitName,
          newProductSellPrice: newProductSellPrice,
        ),
        quantity: quantity,
        unitPrice: unitPrice,
        batchNo: batchNo,
        expiryDate: expiryDate,
      ),
      previous: _line,
    );
    switch (check) {
      case InvoiceLineValid(:final line):
        ref.read(invoiceReviewProvider(key.invoiceId).notifier).putLine(line);
        state = state.copyWith(issues: const {}, done: true);
      case InvoiceLineInvalid(:final issues):
        state = state.copyWith(issues: issues);
    }
  }

  LineChoiceInput _choiceInput({
    required String newProductName,
    required String newProductBaseUnitName,
    required String newProductSellPrice,
  }) {
    final productId = state.productId;
    final unitId = state.unitId;
    return switch (state.mode) {
      LineProductMode.none => const LineChoiceInput.none(),
      LineProductMode.newProduct => LineChoiceInput.newProduct(
        name: newProductName,
        baseUnitName: newProductBaseUnitName,
        sellPrice: newProductSellPrice,
      ),
      LineProductMode.existing when productId != null =>
        LineChoiceInput.existing(
          productId: productId,
          productName: state.productName ?? '',
          unitId: unitId,
          unitName: _unitName(unitId),
        ),
      LineProductMode.existing => const LineChoiceInput.none(),
    };
  }

  /// The name of [unitId] from the loaded units, or from the line itself
  /// while the units are still loading.
  String? _unitName(String? unitId) {
    for (final unit in [...?state.units]) {
      if (unit.id == unitId) {
        return unit.name;
      }
    }
    final choice = _line?.choice;
    return choice is ExistingProductChoice && choice.productUnitId == unitId
        ? choice.unitName
        : null;
  }
}

final NotifierProviderFamily<
  InvoiceLineEditorNotifier,
  InvoiceLineEditorState,
  InvoiceLineKey
>
invoiceLineEditorProvider = NotifierProvider.autoDispose
    .family<InvoiceLineEditorNotifier, InvoiceLineEditorState, InvoiceLineKey>(
      InvoiceLineEditorNotifier.new,
    );
