import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_input_rules.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/products/presentation/providers/unit_form_state.dart';

/// Adds (P6), edits (P7) or deletes (P8) a unit of a product.
final class UnitFormNotifier extends Notifier<UnitFormState> {
  new(this.args);

  final UnitFormArgs args;

  /// Contract P6/P7 request field names.
  static const Map<String, ProductField> wireFields = {
    'name': ProductField.unitName,
    'factor': ProductField.unitFactor,
    'sellPrice': ProductField.unitSellPrice,
    'barcode': ProductField.unitBarcode,
  };

  /// Codes shown under their field.
  static const Map<ApiErrorCode, ProductField> codeFields = {
    ApiErrorCode.productUnitNameRequired: ProductField.unitName,
    ApiErrorCode.productUnitDuplicateName: ProductField.unitName,
    ApiErrorCode.productUnitDuplicateBarcode: ProductField.unitBarcode,
    ApiErrorCode.productUnitBaseUnitFactorFixed: ProductField.unitFactor,
  };

  @override
  UnitFormState build() => const UnitFormState();

  Future<void> save({
    required String name,
    required String factor,
    required String sellPrice,
    required String barcode,
  }) async {
    if (state.isBusy) {
      return;
    }
    switch (ProductInputRules.unit(
      name: name,
      factor: factor,
      sellPrice: sellPrice,
      barcode: barcode,
    )) {
      case ProductInputInvalid(:final issues):
        state = UnitFormState(errors: ProductFormErrors(issues: issues));
      case ProductInputValid(:final value):
        state = const UnitFormState(isSubmitting: true);
        final unitId = args.unitId;
        final result = unitId == null
            ? await ref.read(addUnitUseCaseProvider).call(args.productId, value)
            : await ref
                  .read(updateUnitUseCaseProvider)
                  .call(args.productId, unitId, value);
        _finish(result, UnitFormOutcome.saved);
    }
  }

  /// Deletes the unit being edited.
  Future<void> delete() async {
    final unitId = args.unitId;
    if (state.isBusy || unitId == null) {
      return;
    }
    state = const UnitFormState(isDeleting: true);
    final result = await ref
        .read(deleteUnitUseCaseProvider)
        .call(args.productId, unitId);
    _finish(result, UnitFormOutcome.deleted);
  }

  void _finish(Result<Object?, Failure> result, UnitFormOutcome outcome) {
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok():
        ref
          ..invalidate(productDetailProvider(args.productId))
          ..invalidate(productListProvider);
        state = UnitFormState(outcome: outcome);
      case Err(:final failure):
        state = UnitFormState(
          errors: ProductFormErrors.fromFailure(
            failure,
            wireFields: wireFields,
            codeFields: codeFields,
          ),
        );
    }
  }
}

final NotifierProviderFamily<UnitFormNotifier, UnitFormState, UnitFormArgs>
unitFormProvider = NotifierProvider.autoDispose
    .family<UnitFormNotifier, UnitFormState, UnitFormArgs>(
      UnitFormNotifier.new,
    );
