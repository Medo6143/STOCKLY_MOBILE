import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';

/// The `status` query of `/invoices` (design §3.1): the contract's status
/// names, so `/invoices?status=NeedsReview` reads like the API.
abstract final class InvoiceRouteQuery {
  static const Map<InvoiceStatus, String> _values = {
    InvoiceStatus.processing: 'Processing',
    InvoiceStatus.needsReview: 'NeedsReview',
    InvoiceStatus.confirmed: 'Confirmed',
    InvoiceStatus.failed: 'Failed',
  };

  /// The status of a query value; `null` (every status) for anything else.
  static InvoiceStatus? parse(String? value) {
    for (final MapEntry(:key, value: name) in _values.entries) {
      if (name == value) {
        return key;
      }
    }
    return null;
  }

  static String valueOf(InvoiceStatus status) => _values[status]!;
}
