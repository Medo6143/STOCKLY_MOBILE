import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// The first page of products matching a search (P1), for the product
/// picker of the line editor. Archived products are left out.
final class ProductPickerNotifier extends AsyncNotifier<List<ProductListItem>> {
  new(this.search);

  final String search;

  @override
  Future<List<ProductListItem>> build() async {
    final page =
        await (await ref
                .watch(getProductsUseCaseProvider)
                .call(ProductQuery(search: search), page: 1))
            .toFuture();
    return page.items;
  }
}

final AsyncNotifierProviderFamily<
  ProductPickerNotifier,
  List<ProductListItem>,
  String
>
productPickerProvider = AsyncNotifierProvider.autoDispose
    .family<ProductPickerNotifier, List<ProductListItem>, String>(
      ProductPickerNotifier.new,
    );
