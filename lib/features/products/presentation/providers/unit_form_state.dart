import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';

part 'unit_form_state.freezed.dart';

/// The family key of the unit form: [unitId] is `null` to add a unit.
@freezed
abstract class UnitFormArgs with _$UnitFormArgs {
  const factory({required String productId, String? unitId}) = _UnitFormArgs;
}

/// How the unit form finished.
enum UnitFormOutcome { saved, deleted }

/// The unit form (design §11): loading while [isSubmitting] or
/// [isDeleting], errors under fields or in the banner, and [outcome] once
/// the server accepted the change.
@freezed
abstract class UnitFormState with _$UnitFormState {
  const factory({
    @Default(false) bool isSubmitting,
    @Default(false) bool isDeleting,
    @Default(ProductFormErrors()) ProductFormErrors errors,
    UnitFormOutcome? outcome,
  }) = _UnitFormState;
}

extension UnitFormStateX on UnitFormState {
  bool get isBusy => isSubmitting || isDeleting;
}
