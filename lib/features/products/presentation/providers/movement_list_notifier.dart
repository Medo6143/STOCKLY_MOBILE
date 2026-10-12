import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

/// The stock history of one product (P11), newest first, page by page.
final class MovementListNotifier extends PagedNotifier<StockMovement> {
  new(this.productId);

  final String productId;

  @override
  Future<Result<Paged<StockMovement>, Failure>> fetchPage(int page) =>
      ref.read(getMovementsUseCaseProvider).call(productId, page: page);
}

final AsyncNotifierProviderFamily<
  MovementListNotifier,
  PagedState<StockMovement>,
  String
>
movementListProvider = AsyncNotifierProvider.autoDispose
    .family<MovementListNotifier, PagedState<StockMovement>, String>(
      MovementListNotifier.new,
    );
