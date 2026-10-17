import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The status of an invoice as a soft pill; its colours animate when the
/// status changes.
class InvoiceStatusChip extends StatelessWidget {
  const new({required this.status, super.key});

  final InvoiceStatus status;

  /// The tone of [status], shared with the list row's badge.
  static PillTone toneOf(InvoiceStatus status) => switch (status) {
    InvoiceStatus.processing => PillTone.neutral,
    InvoiceStatus.needsReview => PillTone.warning,
    InvoiceStatus.confirmed => PillTone.mint,
    InvoiceStatus.failed => PillTone.danger,
  };

  @override
  Widget build(BuildContext context) => StatusPill(
    label: invoiceStatusLabel(AppLocalizations.of(context), status),
    tone: toneOf(status),
  );
}
