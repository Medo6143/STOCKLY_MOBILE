import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// The product list for one [query] (P1), page by page.
final class ProductListNotifier extends PagedNotifier<ProductListItem> {
  new(this.query);

  final ProductQuery query;

  @override
  Future<Result<Paged<ProductListItem>, Failure>> fetchPage(int page) =>
      ref.read(getProductsUseCaseProvider).call(query, page: page);
}

final AsyncNotifierProviderFamily<
  ProductListNotifier,
  PagedState<ProductListItem>,
  ProductQuery
>
productListProvider = AsyncNotifierProvider.autoDispose
    .family<ProductListNotifier, PagedState<ProductListItem>, ProductQuery>(
      ProductListNotifier.new,
    );
