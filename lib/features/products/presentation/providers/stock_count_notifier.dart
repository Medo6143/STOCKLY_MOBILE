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

/// The Owner's stock count (P10) of one product. A matching count changes
/// nothing (`changed: false`).
final class StockCountNotifier extends Notifier<StockCountState> {
  new(this.productId);

  final String productId;

  /// Contract P10 request field names.
  static const Map<String, ProductField> wireFields = {
    'countedQuantity': ProductField.countedQuantity,
    'unitId': ProductField.stockUnit,
  };

  /// Codes shown under their field.
  static const Map<ApiErrorCode, ProductField> codeFields = {
    ApiErrorCode.productUnitNotFound: ProductField.stockUnit,
  };

  @override
  StockCountState build() => const StockCountState();

  /// [unitId] `null` means the base unit.
  Future<void> submit({
    required String countedQuantity,
    required String? unitId,
  }) async {
    if (state.isSubmitting) {
      return;
    }
    switch (ProductInputRules.count(
      countedQuantity: countedQuantity,
      unitId: unitId,
    )) {
      case ProductInputInvalid(:final issues):
        state = StockCountState(errors: ProductFormErrors(issues: issues));
      case ProductInputValid(:final value):
        state = const StockCountState(isSubmitting: true);
        final result = await ref
            .read(recordStockCountUseCaseProvider)
            .call(productId, value);
        if (!ref.mounted) {
          return;
        }
        switch (result) {
          case Ok(value: final counted):
            if (counted.changed) {
              ref
                ..invalidate(productDetailProvider(productId))
                ..invalidate(productListProvider)
                ..invalidate(movementListProvider(productId));
            }
            state = StockCountState(result: counted);
          case Err(:final failure):
            state = StockCountState(
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

final NotifierProviderFamily<StockCountNotifier, StockCountState, String>
stockCountProvider = NotifierProvider.autoDispose
    .family<StockCountNotifier, StockCountState, String>(
      StockCountNotifier.new,
    );
