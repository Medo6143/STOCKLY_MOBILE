import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/offline_banner.dart';
import 'package:stockly/core/widgets/paged_list_view.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_list_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_list_tile.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_status_filter_chips.dart';
import 'package:stockly/features/invoices/presentation/widgets/pending_scans_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Invoice history (I2, design §11) with the status filter, the "scans
/// waiting to upload" card and the scan button. States: loading = the
/// first page; empty = "No invoices yet" with scan (or the empty filter);
/// error = retry (a failed later page shows inline); data = the pages.
class InvoiceListScreen extends ConsumerStatefulWidget {
  const new({this.initialStatus, super.key});

  /// The filter from the route (`status=NeedsReview`).
  final InvoiceStatus? initialStatus;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  late InvoiceStatus? _status = widget.initialStatus;

  void _scan() => context.goNamed(RouteNames.scanCapture);

  Future<void> _refresh() async {
    try {
      final provider = invoiceListProvider(_status);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = invoiceListProvider(_status);
    final pending = ref.watch(pendingScanCountProvider).value ?? 0;
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navInvoices)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _scan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: Text(l10n.invoicesScanAction),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (pending > 0)
            PendingScansCard(
              count: pending,
              onTap: () => context.goNamed(RouteNames.scanQueue),
            ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(
              vertical: context.spacing.xs,
            ),
            child: InvoiceStatusFilterChips(
              selected: _status,
              onChanged: (status) => setState(() => _status = status),
            ),
          ),
          Expanded(
            child: AsyncStateView<PagedState<InvoiceListItem>>(
              value: ref.watch(provider),
              isEmpty: (page) => page.items.isEmpty,
              empty: _status == null
                  ? EmptyState(
                      title: l10n.invoicesListEmptyTitle,
                      body: l10n.invoicesListEmptyBody,
                      action: EmptyStateAction(
                        label: l10n.invoicesScanAction,
                        onPressed: _scan,
                      ),
                    )
                  : EmptyState(
                      title: l10n.invoicesListFilteredEmptyTitle,
                      body: l10n.invoicesListFilteredEmptyBody,
                    ),
              onRetry: () => ref.invalidate(provider),
              data: (context, page) => PagedListView<InvoiceListItem>(
                state: page,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: _refresh,
                itemBuilder: (context, item) => InvoiceListTile(
                  item: item,
                  onTap: () => context.goNamed(
                    RouteNames.invoiceDetail,
                    pathParameters: {RoutePaths.invoiceIdParameter: item.id},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
