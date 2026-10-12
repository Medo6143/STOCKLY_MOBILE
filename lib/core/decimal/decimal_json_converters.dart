import 'package:json_annotation/json_annotation.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

/// JSON converters for the contract's decimal strings (design §5.2). A JSON
/// number or a malformed string fails parsing, which becomes
/// `MalformedResponseFailure`. Requests are always sent as strings.
final class MoneyConverter implements JsonConverter<Money, String> {
  const new();

  @override
  Money fromJson(String json) => Money.fromApi(json);

  @override
  String toJson(Money object) => object.toApi();
}

final class NullableMoneyConverter implements JsonConverter<Money?, String?> {
  const new();

  @override
  Money? fromJson(String? json) => json == null ? null : Money.fromApi(json);

  @override
  String? toJson(Money? object) => object?.toApi();
}

final class QuantityConverter implements JsonConverter<Quantity, String> {
  const new();

  @override
  Quantity fromJson(String json) => Quantity.fromApi(json);

  @override
  String toJson(Quantity object) => object.toApi();
}

final class NullableQuantityConverter
    implements JsonConverter<Quantity?, String?> {
  const new();

  @override
  Quantity? fromJson(String? json) =>
      json == null ? null : Quantity.fromApi(json);

  @override
  String? toJson(Quantity? object) => object?.toApi();
}

final class UnitFactorConverter implements JsonConverter<UnitFactor, String> {
  const new();

  @override
  UnitFactor fromJson(String json) => UnitFactor.fromApi(json);

  @override
  String toJson(UnitFactor object) => object.toApi();
}

final class MatchConfidenceConverter
    implements JsonConverter<MatchConfidence, String> {
  const new();

  @override
  MatchConfidence fromJson(String json) => MatchConfidence.fromApi(json);

  @override
  String toJson(MatchConfidence object) => object.toString();
}

final class NullableMatchConfidenceConverter
    implements JsonConverter<MatchConfidence?, String?> {
  const new();

  @override
  MatchConfidence? fromJson(String? json) =>
      json == null ? null : MatchConfidence.fromApi(json);

  @override
  String? toJson(MatchConfidence? object) => object?.toString();
}
