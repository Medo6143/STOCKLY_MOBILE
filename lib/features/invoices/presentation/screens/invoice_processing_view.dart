import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_processing_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_processing_state.dart';
import 'package:stockly/features/invoices/presentation/widgets/reading_invoice_animation.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Waiting for the AI extraction (design §11): I3 every 2 s for up to 60 s.
/// States: loading = "Reading the invoice…" (static under reduce motion);
/// empty = after 60 s still processing, "you can leave", with refresh;
/// error = the last poll failed when the window ended, with retry; data =
/// the invoice left `Processing`, the detail screen shows its view.
class InvoiceProcessingView extends ConsumerWidget {
  const new({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = invoiceProcessingProvider(invoiceId);
    final state = ref.watch(provider);
    final restart = ref.read(provider.notifier).restart;
    final failure = state.failure;
    return switch (state.phase) {
      InvoiceProcessingPhase.polling => Center(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.all(context.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ReadingInvoiceAnimation(),
              SizedBox(height: context.spacing.lg),
              Text(
                l10n.invoiceProcessingTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                l10n.invoiceProcessingBody,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      InvoiceProcessingPhase.finished => const LoadingState(),
      InvoiceProcessingPhase.stillProcessing => EmptyState(
        title: l10n.invoiceProcessingStillTitle,
        body: l10n.invoiceProcessingStillBody,
        action: EmptyStateAction(
          label: l10n.invoiceProcessingRefresh,
          onPressed: restart,
        ),
      ),
      InvoiceProcessingPhase.failed when failure != null => ErrorState(
        failure: failure,
        onRetry: restart,
      ),
      InvoiceProcessingPhase.failed => EmptyState(
        title: l10n.invoiceProcessingStillTitle,
        body: l10n.invoiceProcessingStillBody,
        action: EmptyStateAction(
          label: l10n.invoiceProcessingRefresh,
          onPressed: restart,
        ),
      ),
    };
  }
}
