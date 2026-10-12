import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_input_rules.dart';
import 'package:stockly/features/products/presentation/providers/movement_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/products/presentation/providers/stock_change_states.dart';

/// The Owner's manual stock correction (P9) of one product.
final class StockAdjustmentNotifier extends Notifier<StockAdjustmentState> {
  new(this.productId);

  final String productId;

  /// Contract P9 request field names.
  static const Map<String, ProductField> wireFields = {
    'quantityChange': ProductField.quantityChange,
    'unitId': ProductField.stockUnit,
    'note': ProductField.note,
  };

  /// Codes shown under their field.
  static const Map<ApiErrorCode, ProductField> codeFields = {
    ApiErrorCode.stockZeroChange: ProductField.quantityChange,
    ApiErrorCode.stockNoteRequired: ProductField.note,
    ApiErrorCode.productUnitNotFound: ProductField.stockUnit,
  };

  @override
  StockAdjustmentState build() => const StockAdjustmentState();

  /// [unitId] `null` means the base unit.
  Future<void> submit({
    required String quantityChange,
    required String? unitId,
    required String note,
  }) async {
    if (state.isSubmitting) {
      return;
    }
    switch (ProductInputRules.adjustment(
      quantityChange: quantityChange,
      unitId: unitId,
      note: note,
    )) {
      case ProductInputInvalid(:final issues):
        state = StockAdjustmentState(errors: ProductFormErrors(issues: issues));
      case ProductInputValid(:final value):
        state = const StockAdjustmentState(isSubmitting: true);
        final result = await ref
            .read(adjustStockUseCaseProvider)
            .call(productId, value);
        if (!ref.mounted) {
          return;
        }
        switch (result) {
          case Ok(value: final movement):
            ref
              ..invalidate(productDetailProvider(productId))
              ..invalidate(productListProvider)
              ..invalidate(movementListProvider(productId));
            state = StockAdjustmentState(movement: movement);
          case Err(:final failure):
            state = StockAdjustmentState(
              errors: ProductFormErrors.fromFailure(
                failure,
                wireFields: wireFields,
                codeFields: codeFields,
              ),
            );
        }
    }
  }
}

final NotifierProviderFamily<
  StockAdjustmentNotifier,
  StockAdjustmentState,
  String
>
stockAdjustmentProvider = NotifierProvider.autoDispose
    .family<StockAdjustmentNotifier, StockAdjustmentState, String>(
      StockAdjustmentNotifier.new,
    );
