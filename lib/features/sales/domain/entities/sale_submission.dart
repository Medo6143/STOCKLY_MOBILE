import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';

part 'sale_submission.freezed.dart';

/// The answer to S1: `201` for a new sale, `200` when an earlier attempt
/// with the same `clientRequestId` had already recorded it.
@freezed
sealed class SaleSubmission with _$SaleSubmission {
  const factory created(Sale sale) = SaleCreated;

  const factory alreadyRecorded(Sale sale) = SaleAlreadyRecorded;
}
