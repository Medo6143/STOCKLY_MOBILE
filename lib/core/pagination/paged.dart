import 'package:freezed_annotation/freezed_annotation.dart';

part 'paged.freezed.dart';

/// One page of a list (contract §1.3), shared by every paged endpoint.
@freezed
abstract class Paged<T> with _$Paged<T> {
  const factory({
    required List<T> items,
    required int page,
    required int pageSize,
    required int totalCount,
  }) = _Paged<T>;
}

extension PagedX<T> on Paged<T> {
  /// `true` while pages after this one exist.
  bool get hasMore => page * pageSize < totalCount;
}
