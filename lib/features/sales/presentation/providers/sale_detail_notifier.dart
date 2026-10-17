import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

/// One sale (S3).
final class SaleDetailNotifier extends AsyncNotifier<Sale> {
  new(this.saleId);

  final String saleId;

  @override
  Future<Sale> build() => ref
      .watch(getSaleUseCaseProvider)
      .call(saleId)
      .then((result) => result.toFuture());
}

final AsyncNotifierProviderFamily<SaleDetailNotifier, Sale, String>
saleDetailProvider = AsyncNotifierProvider.autoDispose
    .family<SaleDetailNotifier, Sale, String>(SaleDetailNotifier.new);
