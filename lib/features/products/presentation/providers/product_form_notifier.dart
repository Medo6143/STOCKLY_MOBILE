import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_input_rules.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';
import 'package:stockly/features/products/presentation/providers/product_form_state.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// What the user typed in the product form.
final class ProductFormInput {
  const new({
    required this.name,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.lowStockThreshold,
    this.baseUnitName = '',
    this.baseUnitSellPrice = '',
    this.openingQuantity = '',
  });

  final String name;
  final String barcode;
  final String category;
  final String costPrice;
  final String lowStockThreshold;

  /// Create only.
  final String baseUnitName;

  /// Create only.
  final String baseUnitSellPrice;

  /// Create only, Owner only.
  final String openingQuantity;
}

/// Creates (P3) or edits (P4) a product. [productId] is `null` for create.
/// Only the Owner sends an opening quantity; a `403` is still shown if the
/// role changed meanwhile.
final class ProductFormNotifier extends Notifier<ProductFormState> {
  new(this.productId);

  final String? productId;

  /// Contract P3/P4 request field names.
  static const Map<String, ProductField> wireFields = {
    'name': ProductField.name,
    'barcode': ProductField.barcode,
    'category': ProductField.category,
    'baseUnitName': ProductField.baseUnitName,
    'costPrice': ProductField.costPrice,
    'baseUnitSellPrice': ProductField.baseUnitSellPrice,
    'lowStockThreshold': ProductField.lowStockThreshold,
    'openingQuantity': ProductField.openingQuantity,
  };

  /// Codes shown under their field.
  static const Map<ApiErrorCode, ProductField> codeFields = {
    ApiErrorCode.productNameRequired: ProductField.name,
    ApiErrorCode.productUnitNameRequired: ProductField.baseUnitName,
    ApiErrorCode.productDuplicateBarcode: ProductField.barcode,
  };

  @override
  ProductFormState build() => const ProductFormState();

  Future<void> submit(ProductFormInput input) async {
    if (state.isSubmitting) {
      return;
    }
    final productId = this.productId;
    final Future<Result<ProductDetail, Failure>> Function() send;
    if (productId == null) {
      switch (ProductInputRules.create(
        name: input.name,
        barcode: input.barcode,
        category: input.category,
        baseUnitName: input.baseUnitName,
        costPrice: input.costPrice,
        baseUnitSellPrice: input.baseUnitSellPrice,
        lowStockThreshold: input.lowStockThreshold,
        openingQuantity: input.openingQuantity,
        includeOpening: ref.read(isOwnerProvider),
      )) {
        case ProductInputInvalid(:final issues):
          state = ProductFormState(errors: ProductFormErrors(issues: issues));
          return;
        case ProductInputValid(:final value):
          send = () => ref.read(createProductUseCaseProvider).call(value);
      }
    } else {
      switch (ProductInputRules.update(
        name: input.name,
        barcode: input.barcode,
        category: input.category,
        costPrice: input.costPrice,
        lowStockThreshold: input.lowStockThreshold,
      )) {
        case ProductInputInvalid(:final issues):
          state = ProductFormState(errors: ProductFormErrors(issues: issues));
          return;
        case ProductInputValid(:final value):
          send = () =>
              ref.read(updateProductUseCaseProvider).call(productId, value);
      }
    }
    state = const ProductFormState(isSubmitting: true);
    final result = await send();
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        ref.invalidate(productListProvider);
        if (productId != null) {
          ref.invalidate(productDetailProvider(productId));
        }
        state = ProductFormState(saved: value);
      case Err(:final failure):
        state = ProductFormState(
          errors: ProductFormErrors.fromFailure(
            failure,
            wireFields: wireFields,
            codeFields: codeFields,
          ),
        );
    }
  }
}

final NotifierProviderFamily<ProductFormNotifier, ProductFormState, String?>
productFormProvider = NotifierProvider.autoDispose
    .family<ProductFormNotifier, ProductFormState, String?>(
      ProductFormNotifier.new,
    );
