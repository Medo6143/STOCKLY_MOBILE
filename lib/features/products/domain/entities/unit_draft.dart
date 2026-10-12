import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

part 'unit_draft.freezed.dart';

/// A unit to add or update (contract P6, P7).
@freezed
abstract class UnitDraft with _$UnitDraft {
  const factory({
    required String name,
    required UnitFactor factor,
    required Money sellPrice,
    required String? barcode,
  }) = _UnitDraft;
}
