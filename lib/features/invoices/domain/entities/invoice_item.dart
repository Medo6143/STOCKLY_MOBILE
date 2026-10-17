import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';

part 'invoice_item.freezed.dart';

/// One invoice line (contract `InvoiceItemDto`). [quantity] is in the
/// line's unit; [lineTotal] is computed by the server.
@freezed
abstract class InvoiceItem with _$InvoiceItem {
  const factory({
    required String id,
    required int lineNo,
    required String rawName,
    required String? productId,
    required String? productName,
    required String? productUnitId,
    required String? unitName,
    required Quantity quantity,
    required Money unitPrice,
    required Money lineTotal,
    required CalendarDate? expiryDate,
    required String? batchNo,
    required MatchConfidence? matchConfidence,
    required NewProduct? newProduct,
  }) = _InvoiceItem;
}
