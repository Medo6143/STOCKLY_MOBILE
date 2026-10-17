import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_line_editor_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_line_editor_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_state.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/features/invoices/presentation/widgets/new_product_form.dart';
import 'package:stockly/features/invoices/presentation/widgets/product_picker_sheet.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Edits one line of the review draft in memory (design §11): raw name,
/// product (picker) and one of its units, or a new product, quantity, unit
/// price, expiry and batch. States: loading = the invoice, and the units
/// of the chosen product; empty = the picker's "No products match" with
/// "Create new product" (a line beyond 100 or a read-only invoice shows
/// why it cannot be edited); error = field issues and a units failure with
/// retry; data = the line form. "Done" writes the draft only.
class InvoiceLineEditorScreen extends ConsumerWidget {
  const new({required this.invoiceId, required this.lineNo, super.key});

  final String invoiceId;
  final int lineNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = invoiceReviewProvider(invoiceId);
    final line = ref.watch(provider).value?.draft.lineByNo(lineNo);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          line == null
              ? l10n.invoiceLineNewTitle
              : l10n.invoiceLineNo(ltrIsolate('$lineNo')),
        ),
      ),
      body: AsyncStateView<InvoiceReviewState>(
        loading: const LoadingState(shape: LoadingShape.form),
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        isEmpty: (s) =>
            s.isReadOnly ||
            (s.draft.lineByNo(lineNo) == null && !s.draft.canAddLine),
        empty: EmptyState(
          title: l10n.invoiceReviewReadOnly,
          body: l10n.invoiceReviewMaxLines,
        ),
        data: (context, review) => _LineForm(
          lineKey: (invoiceId: invoiceId, lineNo: lineNo),
          line: review.draft.lineByNo(lineNo),
        ),
      ),
    );
  }
}

class _LineForm extends ConsumerStatefulWidget {
  const new({required this.lineKey, required this.line});

  final InvoiceLineKey lineKey;

  /// `null` for a new line.
  final InvoiceLineDraft? line;

  @override
  ConsumerState<_LineForm> createState() => _LineFormState();
}

class _LineFormState extends ConsumerState<_LineForm> {
  static const double _sheetHeightFactor = 0.9;
  static const int _firstYear = 2000;
  static const int _lastYear = 2100;

  late final InvoiceLineDraft? _line = widget.line;
  late final TextEditingController _rawName = TextEditingController(
    text: _line?.rawName,
  );
  late final TextEditingController _quantity = TextEditingController(
    text: _line?.quantity.toApi(),
  );
  late final TextEditingController _unitPrice = TextEditingController(
    text: _line?.unitPrice.toApi(),
  );
  late final TextEditingController _batch = TextEditingController(
    text: _line?.batchNo,
  );
  late final NewProductChoice? _newProduct = switch (_line?.choice) {
    final NewProductChoice choice => choice,
    _ => null,
  };
  late final TextEditingController _newName = TextEditingController(
    text: _newProduct?.product.name,
  );
  late final TextEditingController _newUnit = TextEditingController(
    text: _newProduct?.product.baseUnitName,
  );
  late final TextEditingController _newPrice = TextEditingController(
    text: _newProduct?.product.sellPrice.toApi(),
  );
  late CalendarDate? _expiry = _line?.expiryDate;

  @override
  void dispose() {
    for (final controller in [
      _rawName,
      _quantity,
      _unitPrice,
      _batch,
      _newName,
      _newUnit,
      _newPrice,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  InvoiceLineEditorNotifier get _notifier =>
      ref.read(invoiceLineEditorProvider(widget.lineKey).notifier);

  Future<void> _pickProduct() async {
    final result = await showModalBottomSheet<ProductPickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: _sheetHeightFactor,
        child: ProductPickerSheet(initialSearch: _rawName.text),
      ),
    );
    switch (result) {
      case ProductPicked(:final product):
        _notifier.chooseProduct(productId: product.id, name: product.name);
      case NewProductRequested():
        if (_newName.text.trim().isEmpty) {
          _newName.text = _rawName.text.trim();
        }
        _notifier.chooseNewProduct();
      case null:
        break;
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry?.toDateTime(),
      firstDate: DateTime(_firstYear),
      lastDate: DateTime(_lastYear),
    );
    if (picked != null) {
      setState(() => _expiry = CalendarDate.fromDateTime(picked));
    }
  }

  void _save() => _notifier.save(
    rawName: _rawName.text,
    quantity: _quantity.text,
    unitPrice: _unitPrice.text,
    batchNo: _batch.text,
    expiryDate: _expiry,
    newProductName: _newName.text,
    newProductBaseUnitName: _newUnit.text,
    newProductSellPrice: _newPrice.text,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = invoiceLineEditorProvider(widget.lineKey);
    final editor = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.done && !(previous?.done ?? false)) {
        Navigator.of(context).maybePop();
      }
    });
    String? error(InvoiceLineField field) {
      final issue = editor.issues[field];
      return issue == null ? null : invoiceFieldIssueLabel(l10n, issue);
    }

    final language = Localizations.localeOf(context).languageCode;
    final expiry = _expiry;
    final gap = SizedBox(height: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        TextField(
          controller: _rawName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.invoiceLineRawName,
            errorText: error(InvoiceLineField.rawName),
          ),
        ),
        gap,
        _ProductSection(
          editor: editor,
          productError: error(InvoiceLineField.product),
          unitError: error(InvoiceLineField.unit),
          onPick: _pickProduct,
          onUnit: _notifier.chooseUnit,
          onRetryUnits: _notifier.retryUnits,
        ),
        if (editor.mode == LineProductMode.newProduct) ...[
          gap,
          NewProductForm(
            name: _newName,
            baseUnitName: _newUnit,
            sellPrice: _newPrice,
            issues: editor.issues,
          ),
        ],
        gap,
        DecimalField(
          controller: _quantity,
          label: l10n.invoiceLineQuantity,
          enabled: true,
          errorText: error(InvoiceLineField.quantity),
        ),
        gap,
        DecimalField(
          controller: _unitPrice,
          label: l10n.invoiceLineUnitPrice,
          enabled: true,
          errorText: error(InvoiceLineField.unitPrice),
        ),
        gap,
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.invoiceLineExpiryLabel,
            suffixIcon: expiry == null
                ? null
                : IconButton(
                    tooltip: l10n.invoiceReviewClearDate,
                    onPressed: () => setState(() => _expiry = null),
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
          child: InkWell(
            onTap: _pickExpiry,
            child: Text(
              expiry == null
                  ? l10n.invoiceReviewPickDate
                  : ltrIsolate(DateFormatter.date(expiry, language)),
            ),
          ),
        ),
        gap,
        TextField(
          controller: _batch,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.invoiceLineBatchLabel),
        ),
        SizedBox(height: spacing.xl),
        FilledButton(onPressed: _save, child: Text(l10n.invoiceLineDone)),
      ],
    );
  }
}

/// The product of the line: choose one, or the chosen one with its units,
/// or the new product header.
class _ProductSection extends StatelessWidget {
  const new({
    required this.editor,
    required this.productError,
    required this.unitError,
    required this.onPick,
    required this.onUnit,
    required this.onRetryUnits,
  });

  final InvoiceLineEditorState editor;
  final String? productError;
  final String? unitError;
  final VoidCallback onPick;
  final ValueChanged<String> onUnit;
  final VoidCallback onRetryUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final units = editor.units;
    final unitsFailure = editor.unitsFailure;
    final productName = editor.productName;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.invoiceLineProduct,
        errorText: productError,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(switch (editor.mode) {
                  LineProductMode.existing when productName != null =>
                    productName,
                  LineProductMode.newProduct =>
                    l10n.invoiceLineNewProductHeader,
                  LineProductMode.existing ||
                  LineProductMode.none => l10n.invoiceLineChooseProduct,
                }),
              ),
              TextButton(
                onPressed: onPick,
                child: Text(
                  editor.mode == LineProductMode.none
                      ? l10n.invoiceLineChooseProduct
                      : l10n.invoiceLineChangeProduct,
                ),
              ),
            ],
          ),
          if (editor.mode == LineProductMode.existing) ...[
            if (editor.unitsLoading)
              LinearProgressIndicator(semanticsLabel: l10n.commonLoading)
            else if (unitsFailure != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      failureMessage(l10n, unitsFailure),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryUnits,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              )
            else if (units != null)
              Padding(
                padding: EdgeInsetsDirectional.only(top: spacing.xs),
                child: DropdownButtonFormField<String>(
                  initialValue: editor.unitId,
                  decoration: InputDecoration(
                    labelText: l10n.invoiceLineUnit,
                    errorText: unitError,
                  ),
                  items: [
                    for (final unit in units)
                      DropdownMenuItem(value: unit.id, child: Text(unit.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onUnit(value);
                    }
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
