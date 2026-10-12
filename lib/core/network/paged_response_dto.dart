import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/pagination/paged.dart';

part 'paged_response_dto.freezed.dart';
part 'paged_response_dto.g.dart';

/// The paged response body of contract §1.3.
@Freezed(genericArgumentFactories: true)
abstract class PagedResponseDto<T> with _$PagedResponseDto<T> {
  const factory({
    required List<T> items,
    required int page,
    required int pageSize,
    required int totalCount,
  }) = _PagedResponseDto<T>;

  factory fromJson(
    Map<String, Object?> json,
    T Function(Object? json) fromJsonT,
  ) => _$PagedResponseDtoFromJson(json, fromJsonT);

  /// Parses a page whose items are JSON objects read by [item].
  factory parse(Object? data, T Function(Map<String, Object?> json) item) =>
      PagedResponseDto.fromJson(
        requireJsonObject(data),
        (json) => item(requireJsonObject(json)),
      );
}

extension PagedResponseDtoX<T> on PagedResponseDto<T> {
  /// The page with each item mapped by [map].
  Paged<R> toPaged<R>(R Function(T item) map) => Paged(
    items: [for (final item in items) map(item)],
    page: page,
    pageSize: pageSize,
    totalCount: totalCount,
  );
}
