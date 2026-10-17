import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';

part 'invoice_line_editor_state.freezed.dart';

/// Which product the edited line points at.
enum LineProductMode { none, existing, newProduct }

/// The line editor (design §11): the chosen product and its units, the
/// field issues of the last attempt, and [done] once the line is in the
/// draft.
@freezed
abstract class InvoiceLineEditorState with _$InvoiceLineEditorState {
  const factory({
    @Default(LineProductMode.none) LineProductMode mode,
    String? productId,
    String? productName,
    String? unitId,

    /// Units of the chosen product, base unit first; `null` while loading
    /// or when no product is chosen.
    List<ProductUnit>? units,
    @Default(false) bool unitsLoading,
    Failure? unitsFailure,
    @Default(<InvoiceLineField, InvoiceFieldIssue>{})
    Map<InvoiceLineField, InvoiceFieldIssue> issues,
    @Default(false) bool done,
  }) = _InvoiceLineEditorState;
}
