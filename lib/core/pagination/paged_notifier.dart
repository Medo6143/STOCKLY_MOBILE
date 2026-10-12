import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_state.dart';

/// A list loaded page by page (design §2.3): [build] loads the first page,
/// [loadMore] appends the next one and keeps the data when it fails.
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  /// Loads page [page] (1-based).
  Future<Result<Paged<T>, Failure>> fetchPage(int page);

  @override
  Future<PagedState<T>> build() async =>
      PagedState.first(await (await fetchPage(1)).toFuture());

  /// Loads the next page, once at a time, only after the first page loaded.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        state.isLoading ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: null),
    );
    final result = await fetchPage(current.page + 1);
    final latest = state.value;
    if (!ref.mounted || latest == null || !latest.isLoadingMore) {
      return;
    }
    state = AsyncData(switch (result) {
      Ok(:final value) => latest.appended(value),
      Err(:final failure) => latest.copyWith(
        isLoadingMore: false,
        loadMoreFailure: failure,
      ),
    });
  }
}
