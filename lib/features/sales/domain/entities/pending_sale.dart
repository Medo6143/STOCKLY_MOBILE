import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';

part 'pending_sale.freezed.dart';

/// A sale that was sent but whose outcome is unknown (design §6.8): it
/// can only be retried with the same request or discarded.
@freezed
abstract class PendingSale with _$PendingSale {
  const factory({
    required SaleRequest request,
    required int attemptCount,
    required DateTime createdAt,
  }) = _PendingSale;
}
