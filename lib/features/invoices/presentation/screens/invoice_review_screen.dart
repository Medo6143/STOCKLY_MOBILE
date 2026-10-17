import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_state.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_line_tile.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_warning_banner.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Review the extracted invoice (I3, I4; design §11): header fields,
/// warnings, every line, save. Confirm (I5) arrives in Sprint 4. States:
/// loading = I3, and a progress bar while saving; empty = no lines were
/// read, "Add lines manually"; error = load failure with retry, save
/// failures in the banner and on their lines; data = the editable draft
/// (read-only when the invoice is not `NeedsReview`).
class InvoiceReviewScreen extends ConsumerWidget {
  const new({required this.invoiceId, super.key});

  final String invoiceId;

  void _openLine(BuildContext context, int lineNo) => context.pushNamed(
    RouteNames.invoiceLineEdit,
    pathParameters: {
      RoutePaths.invoiceIdParameter: invoiceId,
      RoutePaths.lineNoParameter: '$lineNo',
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = invoiceReviewProvider(invoiceId);
    final value = ref.watch(provider);
    final review = value.value;
    ref.listen(provider, (previous, next) {
      final before = previous?.value?.savedCount;
      final after = next.value?.savedCount;
      if (before != null && after != null && after > before) {
        showMessageSnackBar(context, l10n.invoiceReviewSaved);
      }
    });
    final canAdd =
        review != null && !review.isReadOnly && review.draft.canAddLine;
    void addLine() => _openLine(context, review!.draft.nextLineNo);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceReviewTitle),
        actions: [
          if (review != null && !review.isReadOnly)
            TextButton(
              onPressed: review.canSave
                  ? ref.read(provider.notifier).save
                  : null,
              child: Text(l10n.commonSave),
            ),
        ],
      ),
      floatingActionButton:
          review != null && !review.isReadOnly && review.draft.lines.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: canAdd ? addLine : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                canAdd ? l10n.invoiceReviewAddLine : l10n.invoiceReviewMaxLines,
              ),
            )
          : null,
      body: AsyncStateView<InvoiceReviewState>(
        value: value,
        onRetry: () => ref.invalidate(provider),
        isEmpty: (s) => s.draft.lines.isEmpty,
        empty: EmptyState(
          title: l10n.invoiceReviewEmptyTitle,
          body: l10n.invoiceReviewEmptyBody,
          action: canAdd
              ? EmptyStateAction(
                  label: l10n.invoiceReviewAddLine,
                  onPressed: addLine,
                )
              : null,
        ),
        data: (context, state) => _ReviewForm(
          key: ValueKey(state.invoice),
          state: state,
          onOpenLine: (lineNo) => _openLine(context, lineNo),
        ),
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const new({required this.state, required this.onOpenLine, super.key});

  final InvoiceReviewState state;
  final ValueChanged<int> onOpenLine;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final InvoiceHeaderDraft _header = widget.state.draft.header;
  late final TextEditingController _supplier = TextEditingController(
    text: _header.supplierName,
  );
  late final TextEditingController _number = TextEditingController(
    text: _header.invoiceNumber,
  );
  late final TextEditingController _total = TextEditingController(
    text: _header.totalAmount?.toApi(),
  );

  @override
  void dispose() {
    _supplier.dispose();
    _number.dispose();
    _total.dispose();
    super.dispose();
  }

  InvoiceReviewNotifier get _notifier =>
      ref.read(invoiceReviewProvider(widget.state.invoice.id).notifier);

  Future<void> _pickDate(CalendarDate? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current?.toDateTime(),
      firstDate: DateTime(_firstYear),
      lastDate: DateTime(_lastYear),
    );
    if (picked != null) {
      _notifier.setInvoiceDate(CalendarDate.fromDateTime(picked));
    }
  }

  static const int _firstYear = 2000;
  static const int _lastYear = 2100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = widget.state;
    final draft = state.draft;
    final readOnly = state.isReadOnly;
    final enabled = !readOnly && !state.isSaving;
    final failure = state.failure;
    final language = Localizations.localeOf(context).languageCode;
    final date = draft.header.invoiceDate;
    final computed = state.invoice.computedTotal;
    final totalIssue = state.totalAmountIssue;
    final gap = SizedBox(height: spacing.md);
    final gutter = EdgeInsetsDirectional.symmetric(horizontal: spacing.md);
    return Column(
      children: [
        if (state.isSaving) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: EdgeInsetsDirectional.only(
              top: spacing.md,
              bottom: spacing.huge * 2,
            ),
            children: [
              if (readOnly) ...[
                Padding(
                  padding: gutter,
                  child: FormBanner(message: l10n.invoiceReviewReadOnly),
                ),
                gap,
              ],
              if (failure != null) ...[
                Padding(
                  padding: gutter,
                  child: FormBanner(message: failureMessage(l10n, failure)),
                ),
                gap,
              ] else if (state.lineErrors.isNotEmpty) ...[
                Padding(
                  padding: gutter,
                  child: FormBanner(
                    message: l10n.errorInvoiceLineProductRequired,
                  ),
                ),
                gap,
              ],
              for (final warning in state.invoice.warnings) ...[
                Padding(
                  padding: gutter,
                  child: InvoiceWarningBanner(warning: warning),
                ),
                SizedBox(height: spacing.xs),
              ],
              Padding(
                padding: gutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _supplier,
                      enabled: enabled,
                      onChanged: _notifier.setSupplierName,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.invoiceSupplierLabel,
                      ),
                    ),
                    gap,
                    TextField(
                      controller: _number,
                      enabled: enabled,
                      onChanged: _notifier.setInvoiceNumber,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.invoiceNumberLabel,
                      ),
                    ),
                    gap,
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.invoiceDateLabel,
                        enabled: enabled,
                        suffixIcon: date == null || !enabled
                            ? null
                            : IconButton(
                                tooltip: l10n.invoiceReviewClearDate,
                                onPressed: () => _notifier.setInvoiceDate(null),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      child: InkWell(
                        onTap: enabled ? () => _pickDate(date) : null,
                        child: Text(
                          date == null
                              ? l10n.invoiceReviewPickDate
                              : ltrIsolate(DateFormatter.date(date, language)),
                        ),
                      ),
                    ),
                    gap,
                    DecimalField(
                      controller: _total,
                      label: l10n.invoiceTotalLabel,
                      enabled: enabled,
                      onChanged: _notifier.setTotalAmount,
                      errorText: totalIssue == null
                          ? null
                          : invoiceFieldIssueLabel(l10n, totalIssue),
                    ),
                    if (computed != null) ...[
                      SizedBox(height: spacing.xs),
                      Row(
                        children: [
                          Expanded(child: Text(l10n.invoiceComputedTotalLabel)),
                          MoneyText(computed),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              gap,
              Padding(
                padding: gutter,
                child: Text(
                  l10n.invoiceLinesHeader,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final line in draft.lines)
                InvoiceLineTile(
                  line: line,
                  hasError: state.lineErrors.contains(line.lineNo),
                  messages: state.lineMessages[line.lineNo] ?? const [],
                  onTap: enabled ? () => widget.onOpenLine(line.lineNo) : null,
                  onRemove: enabled
                      ? () => _notifier.removeLine(line.lineNo)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
