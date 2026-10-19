/// Where a payment stands (contract §12.1 `PaymentStatus`). Only the server
/// decides it (provider callback or reconcile job, ADR-0015 §4); the
/// browser redirect never does.
enum PaymentStatus {
  pending,
  paid,
  failed,
  expired;

  /// No later change is expected: polling stops.
  bool get isFinal => this != PaymentStatus.pending;
}
