import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// An HTTP adapter whose answers are scripted by the test. Records every
/// request it receives.
final class ScriptedAdapter implements HttpClientAdapter {
  new(this.respond);

  /// Answers one request.
  Future<ResponseBody> Function(RequestOptions options) respond;

  final List<RequestOptions> requests = [];

  List<RequestOptions> requestsTo(String path) =>
      requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    requests.add(options);
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response.
ResponseBody jsonBody(
  int status,
  Object? json, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    ...headers,
  },
);

/// A ProblemDetails response with [code].
ResponseBody problemBody(
  int status,
  String code, {
  Map<String, List<String>> headers = const {},
  Map<String, List<String>>? errors,
}) => ResponseBody.fromString(
  jsonEncode({
    'type': 'https://tools.ietf.org/html/rfc9110',
    'title': 'Title never shown',
    'status': status,
    'detail': 'Detail never shown',
    'instance': 'GET /api/x',
    'code': code,
    'traceId': '00-trace-00',
    'correlationId': 'cid-from-body',
    'errors': ?errors,
  }),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/problem+json; charset=utf-8'],
    ...headers,
  },
);

/// An `AuthResponse` body with the given tokens.
Map<String, Object?> authResponseJson({
  required String accessToken,
  required String refreshToken,
  String status = 'Active',
}) => {
  'accessToken': accessToken,
  'accessTokenExpiresAt': '2026-10-12T07:15:00Z',
  'refreshToken': refreshToken,
  'refreshTokenExpiresAt': '2026-11-11T07:00:00Z',
  'user': {
    'id': '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d02',
    'email': 'mona@stockly.test',
    'fullName': 'منى عادل',
    'phone': null,
    'preferredLanguage': 'ar',
  },
  'shop': {
    'id': '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01',
    'name': 'صيدلية الشفاء',
    'shopType': 'Pharmacy',
    'status': status,
    'role': 'Owner',
  },
};
