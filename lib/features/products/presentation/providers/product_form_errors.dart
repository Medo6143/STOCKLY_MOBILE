import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';

part 'product_form_errors.freezed.dart';

/// Where the mistakes of a product, unit, adjustment or count form are
/// shown (design §11): under their field, or in the banner above the form.
/// Chosen by failure type and `code`, never by the server's `title` or
/// `detail`.
@freezed
abstract class ProductFormErrors with _$ProductFormErrors {
  const factory({
    /// Rejected on the device before sending.
    @Default(<ProductField, ProductFieldIssue>{})
    Map<ProductField, ProductFieldIssue> issues,

    /// `Validation.Failed` messages from the server, per field.
    @Default(<ProductField, List<String>>{})
    Map<ProductField, List<String>> serverErrors,

    /// A failure shown under one field (for example a duplicate barcode).
    @Default(<ProductField, Failure>{})
    Map<ProductField, Failure> fieldFailures,

    /// A failure shown in the banner above the form.
    Failure? banner,
  }) = _ProductFormErrors;

  /// Splits a submit [failure]: `Validation.Failed` messages go under the
  /// fields named in [wireFields] (a key that matches no field shows the
  /// banner); a code in [codeFields] goes under its field; anything else
  /// is the banner.
  factory fromFailure(
    Failure failure, {
    required Map<String, ProductField> wireFields,
    required Map<ApiErrorCode, ProductField> codeFields,
  }) {
    switch (failure) {
      case ValidationFailure(:final fieldErrors):
        final matched = <ProductField, List<String>>{};
        var unmatched = fieldErrors.isEmpty;
        for (final MapEntry(:key, :value) in fieldErrors.entries) {
          final field = wireFields[key];
          if (field == null) {
            unmatched = true;
          } else {
            matched[field] = value;
          }
        }
        return ProductFormErrors(
          serverErrors: matched,
          banner: unmatched ? failure : null,
        );
      case ApiFailure(:final code) when codeFields.containsKey(code):
        return ProductFormErrors(fieldFailures: {codeFields[code]!: failure});
      default:
        return ProductFormErrors(banner: failure);
    }
  }
}
