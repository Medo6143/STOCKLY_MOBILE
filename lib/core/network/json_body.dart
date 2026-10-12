/// The JSON object of a 2xx response body. Throws [FormatException]
/// (mapped to `MalformedResponseFailure`) for anything else.
Map<String, Object?> requireJsonObject(Object? data) {
  if (data is Map<String, Object?>) {
    return data;
  }
  throw FormatException('Expected a JSON object, got ${data.runtimeType}');
}
