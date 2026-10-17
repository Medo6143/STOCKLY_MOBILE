/// Paging of the invoice list (design §11).
abstract final class InvoicePaging {
  static const int pageSize = 20;
}

/// Polling of an invoice while the AI reads it (contract I3): every
/// [interval] for up to [window].
abstract final class InvoicePolling {
  static const Duration interval = Duration(seconds: 2);
  static const Duration window = Duration(seconds: 60);

  /// Polls after the first one before the window ends.
  static int get maxRepeats => window.inMicroseconds ~/ interval.inMicroseconds;
}
