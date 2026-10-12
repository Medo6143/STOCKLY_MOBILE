import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// One product with its units (P2) and the Owner's archive action (P5).
final class ProductDetailNotifier extends AsyncNotifier<ProductDetail> {
  new(this.productId);

  final String productId;

  @override
  Future<ProductDetail> build() => ref
      .watch(getProductUseCaseProvider)
      .call(productId)
      .then((result) => result.toFuture());

  /// Archives the product, then reloads it and the lists. Returns the
  /// failure, or `null` on success.
  Future<Failure?> archive() async {
    final result = await ref
        .read(archiveProductUseCaseProvider)
        .call(productId);
    if (!ref.mounted) {
      return null;
    }
    switch (result) {
      case Ok():
        ref
          ..invalidate(productListProvider)
          ..invalidateSelf();
        return null;
      case Err(:final failure):
        return failure;
    }
  }
}

final AsyncNotifierProviderFamily<ProductDetailNotifier, ProductDetail, String>
productDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ProductDetailNotifier, ProductDetail, String>(
      ProductDetailNotifier.new,
    );
