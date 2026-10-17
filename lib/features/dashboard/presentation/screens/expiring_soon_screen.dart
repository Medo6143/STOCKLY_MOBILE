import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/paged_list_view.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/presentation/providers/expiring_soon_notifier.dart';
import 'package:stockly/features/dashboard/presentation/widgets/expiring_item_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Products with stock and an expiry within the chosen window, already
/// expired lines included and marked (D2, design §11), labelled as a hint
/// (ADR-0004). States: loading = the first page;
/// empty = "Nothing expires in the next {days} days"; error = retry (a
/// failed later page shows inline); data = the pages, soonest first.
class ExpiringSoonScreen extends ConsumerStatefulWidget {
  const new({this.initialDays = ExpiringSoonWindow.defaultDays, super.key});

  /// The window from the route (`days=30`).
  final int initialDays;

  @override
  ConsumerState<ExpiringSoonScreen> createState() => _ExpiringSoonScreenState();
}

class _ExpiringSoonScreenState extends ConsumerState<ExpiringSoonScreen> {
  late int _days = widget.initialDays;

  Future<void> _refresh() async {
    try {
      final provider = expiringSoonProvider(_days);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = expiringSoonProvider(_days);
    final today = CalendarDate.fromDateTime(
      ref.watch(clockProvider).now().toLocal(),
    );
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.expiringTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing.md,
              spacing.xs,
              spacing.md,
              0,
            ),
            child: Text(
              l10n.expiringHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.colors.muted),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs,
            ),
            child: Wrap(
              spacing: spacing.xs,
              children: [
                for (final days in ExpiringSoonWindow.choices)
                  ChoiceChip(
                    label: Text(l10n.expiringDaysChip(ltrIsolate('$days'))),
                    selected: days == _days,
                    onSelected: (_) => setState(() => _days = days),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncStateView<PagedState<ExpiringItem>>(
              value: ref.watch(provider),
              isEmpty: (page) => page.items.isEmpty,
              empty: EmptyState(
                title: l10n.expiringEmptyTitle(ltrIsolate('$_days')),
                body: l10n.expiringEmptyBody,
              ),
              onRetry: () => ref.invalidate(provider),
              data: (context, page) => PagedListView<ExpiringItem>(
                state: page,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: _refresh,
                itemBuilder: (context, item) => ExpiringItemTile(
                  item: item,
                  expired: item.isExpiredOn(today),
                  onTap: () => context.goNamed(
                    RouteNames.invoiceDetail,
                    pathParameters: {
                      RoutePaths.invoiceIdParameter: item.invoiceId,
                    },
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
