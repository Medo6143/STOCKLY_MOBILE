import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_detail_notifier.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_confirmed_view.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_failed_view.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_processing_view.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The status router of one invoice (I3, design §11). States: loading =
/// while I3 runs; empty = not applicable; error = `Invoice.NotFound` (also
/// another shop's invoice) with back, or retry; data = the processing,
/// confirmed or failed view. A `NeedsReview` invoice opens the review
/// once; coming back shows a button to open it again.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const new({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _reviewOpened = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(invoiceDetailProvider(widget.invoiceId), (_, next) {
      if (next.value?.status == InvoiceStatus.needsReview && !_reviewOpened) {
        _reviewOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Only when this screen is on top: under the review or a line
          // editor (a deep link) it must not take over the navigation.
          if (mounted &&
              GoRouter.of(context).state.name == RouteNames.invoiceDetail) {
            _openReview();
          }
        });
      }
    }, fireImmediately: true);
  }

  void _openReview() => context.goNamed(
    RouteNames.invoiceReview,
    pathParameters: {RoutePaths.invoiceIdParameter: widget.invoiceId},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = invoiceDetailProvider(widget.invoiceId);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoiceDetailTitle)),
      body: AsyncStateView<InvoiceDetail>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (context, invoice) => switch (invoice.status) {
          InvoiceStatus.processing => InvoiceProcessingView(
            invoiceId: invoice.id,
          ),
          InvoiceStatus.needsReview => EmptyState(
            title: l10n.invoiceNeedsReviewTitle,
            body: l10n.invoiceNeedsReviewBody,
            action: EmptyStateAction(
              label: l10n.invoiceOpenReview,
              onPressed: _openReview,
            ),
          ),
          InvoiceStatus.confirmed => InvoiceConfirmedView(invoice: invoice),
          InvoiceStatus.failed => InvoiceFailedView(
            invoice: invoice,
            onScanAgain: () => context.goNamed(RouteNames.scanCapture),
          ),
        },
      ),
    );
  }
}
