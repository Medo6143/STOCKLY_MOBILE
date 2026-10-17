import 'package:flutter/material.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A list of [PagedState] items with pull to refresh. Reaching the end
/// loads the next page; a failed page shows its message and a retry inline
/// (design §2.3). Items are spaced cards; the first page enters with a
/// staggered fade, later pages and rebuilds do not (design-refresh brief).
class PagedListView<T> extends StatelessWidget {
  const new({
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    super.key,
  });

  final PagedState<T> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: EntranceScope(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(
            spacing.md,
            spacing.xs,
            spacing.md,
            0,
          ),
          itemCount: state.items.length + 1,
          itemBuilder: (context, index) => index < state.items.length
              ? Padding(
                  padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
                  child: Entrance(
                    index: index,
                    child: itemBuilder(context, state.items[index]),
                  ),
                )
              : _footer(context),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final failure = state.loadMoreFailure;
    if (failure != null) {
      return Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          children: [
            Text(l10n.commonLoadMoreError, textAlign: TextAlign.center),
            Text(
              failureMessage(l10n, failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.danger),
            ),
            TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) {
      // Room for the floating action button over the last item.
      return SizedBox(height: spacing.huge * 2);
    }
    if (!state.isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    }
    return Padding(
      padding: EdgeInsetsDirectional.all(spacing.md),
      child: Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
      ),
    );
  }
}
