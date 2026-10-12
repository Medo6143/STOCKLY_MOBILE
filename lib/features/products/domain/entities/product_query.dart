import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_query.freezed.dart';

/// The filters of the product list (contract P1). Also the family key of
/// the list provider, so equal queries share one list.
@freezed
abstract class ProductQuery with _$ProductQuery {
  const factory({
    @Default('') String search,
    @Default(false) bool lowStock,
    @Default(false) bool includeArchived,
  }) = _ProductQuery;
}

extension ProductQueryX on ProductQuery {
  /// The search as sent: trimmed, `null` when blank.
  String? get searchOrNull {
    final value = search.trim();
    return value.isEmpty ? null : value;
  }
}
