import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/error_mapper.dart';

/// Runs an API call and turns every expected error into a [Failure]
/// (design §4.6). Nothing above the data layer catches Dio exceptions.
Future<Result<T, Failure>> safeApiCall<T>(Future<T> Function() call) async {
  try {
    return Ok(await call());
  } on DioException catch (e) {
    return Err(mapDioException(e));
  } on FormatException {
    return const Err(MalformedResponseFailure());
  } on CheckedFromJsonException {
    return const Err(MalformedResponseFailure());
  }
}
