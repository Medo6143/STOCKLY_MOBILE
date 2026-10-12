import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/pagination/paged.dart';

part 'paged_state.freezed.dart';

/// The pages loaded so far (design §2.3). The first page uses `AsyncValue`
/// loading and error; later pages keep the data and show
/// [loadMoreFailure] inline at the end of the list.
@freezed
abstract class PagedState<T> with _$PagedState<T> {
  const factory({
    required List<T> items,
    required int page,
    required int pageSize,
    required int totalCount,
    @Default(false) bool isLoadingMore,
    Failure? loadMoreFailure,
  }) = _PagedState<T>;

  /// The state after the first page.
  factory first(Paged<T> paged) => PagedState(
    items: paged.items,
    page: paged.page,
    pageSize: paged.pageSize,
    totalCount: paged.totalCount,
  );
}

extension PagedStateX<T> on PagedState<T> {
  /// `true` while pages after the last loaded one exist.
  bool get hasMore => page * pageSize < totalCount;

  /// [next] appended after the loaded items.
  PagedState<T> appended(Paged<T> next) => copyWith(
    items: [...items, ...next.items],
    page: next.page,
    totalCount: next.totalCount,
    isLoadingMore: false,
    loadMoreFailure: null,
  );
}
