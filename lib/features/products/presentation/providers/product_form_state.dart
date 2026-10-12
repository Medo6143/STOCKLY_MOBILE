import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';

part 'product_form_state.freezed.dart';

/// The create and edit product form (design §11): loading while
/// [isSubmitting], errors under fields or in the banner, and [saved] once
/// the server accepted it.
@freezed
abstract class ProductFormState with _$ProductFormState {
  const factory({
    @Default(false) bool isSubmitting,
    @Default(ProductFormErrors()) ProductFormErrors errors,
    ProductDetail? saved,
  }) = _ProductFormState;
}
