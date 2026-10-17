import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';

/// Contract S1–S3 and the pending sales of design §6.8. The shop always
/// comes from the access token; `shopId` only scopes the local rows.
abstract interface class SalesRepository {
  /// S1. The request is stored as a pending sale before it is first sent,
  /// and a stored request is sent again byte for byte. The row is removed
  /// once the outcome is known (recorded, or definitely refused).
  Future<Result<SaleSubmission, Failure>> submit(
    SaleRequest request, {
    required String shopId,
    required String userId,
  });

  /// The oldest sale of [shopId] whose outcome is unknown.
  Future<PendingSale?> pendingSale(String shopId);

  /// [pendingSale], emitted again on every change.
  Stream<PendingSale?> watchPendingSale(String shopId);

  /// Drops a pending sale without sending it again.
  Future<void> discardPending(String clientRequestId);

  /// S2, newest first; `from` is a UTC bound or `null`.
  Future<Result<Paged<SaleListItem>, Failure>> getSales({
    required DateTime? from,
    required int page,
    required int pageSize,
  });

  /// S3.
  Future<Result<Sale, Failure>> getSale(String saleId);
}
