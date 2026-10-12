import 'package:flutter/material.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A list of [PagedState] items with pull to refresh. Reaching the end
/// loads the next page; a failed page shows its message and a retry inline
/// (design §2.3).
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
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) => index < state.items.length
          ? itemBuilder(context, state.items[index])
          : _footer(context),
    ),
  );

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
      return SizedBox(height: spacing.huge);
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
