import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';

part 'expiring_item.freezed.dart';

/// A confirmed invoice line that expires soon while its product still has
/// stock (contract D2). A hint, not an exact count (ADR-0004): stock is
/// not tracked per batch.
@freezed
abstract class ExpiringItem with _$ExpiringItem {
  const factory({
    required String productId,
    required String productName,
    required CalendarDate expiryDate,
    required String? batchNo,
    required String invoiceId,
    required Quantity lineQuantity,
    required Quantity currentQuantity,
  }) = _ExpiringItem;
}

extension ExpiringItemX on ExpiringItem {
  /// The expiry date is before [today]: the line is already expired (D2
  /// lists those too while the product has stock).
  bool isExpiredOn(CalendarDate today) => expiryDate.compareTo(today) < 0;
}

/// The "expiring soon" window (contract D2, design §11).
abstract final class ExpiringSoonWindow {
  /// The window when none is chosen.
  static const int defaultDays = 60;

  /// The windows offered as chips.
  static const List<int> choices = [30, 60, 90];

  /// Rows per page.
  static const int pageSize = 20;
}
