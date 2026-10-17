import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/offline_banner.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_notifier.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_state.dart';
import 'package:stockly/features/sales/presentation/widgets/barcode_camera_sheet.dart';
import 'package:stockly/features/sales/presentation/widgets/barcode_entry_field.dart';
import 'package:stockly/features/sales/presentation/widgets/cart_line_tile.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_product_search_sheet.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_total_bar.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Build a cart by barcode or search and record the sale (P12, P1, P2,
/// S1; design §11, §6.8). States: loading = a lookup or the submit
/// (progress bar, "Recording…"); empty = "Scan a barcode or search a
/// product"; error = lookup and submit failures in banners and on their
/// lines, or the locked cart with Retry and Discard when the outcome is
/// unknown; data = the cart lines, note and total. A recorded sale opens
/// its detail.
class QuickSaleScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends ConsumerState<QuickSaleScreen> {
  QuickSaleNotifier get _notifier => ref.read(quickSaleProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_notifier.restorePending());
  }

  Future<void> _search() async {
    final product = await showModalBottomSheet<ProductListItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SaleProductSearchSheet(),
    );
    if (product != null) {
      await _notifier.addProduct(product);
    }
  }

  Future<void> _camera() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const BarcodeCameraSheet(),
    );
    if (barcode != null) {
      await _notifier.addBarcode(barcode);
    }
  }

  Future<void> _pickUnit(int key) async {
    await _notifier.loadUnits(key);
    if (!mounted) {
      return;
    }
    final line = ref
        .read(quickSaleProvider)
        .lines
        .where((l) => l.key == key)
        .firstOrNull;
    if (line == null) {
      return;
    }
    final unitId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => _UnitSheet(line: line),
    );
    if (unitId != null) {
      _notifier.setUnit(key, unitId);
    }
  }

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.salesDiscardTitle),
        content: Text(l10n.salesDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.salesDiscard),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _notifier.discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = ref.watch(quickSaleProvider);
    ref.listen(quickSaleProvider, (previous, next) {
      final submission = next.lastSubmission;
      if (previous != null &&
          next.submissionCount > previous.submissionCount &&
          submission != null) {
        context.goNamed(
          RouteNames.saleDetail,
          pathParameters: {RoutePaths.saleIdParameter: submission.sale.id},
          queryParameters: {
            if (submission is SaleAlreadyRecorded)
              RoutePaths.repeatParameter: RoutePaths.trueValue,
          },
        );
      }
    });
    final editable = state.isEditable;
    final banner = _banner(l10n, state);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesQuickSaleTitle),
        actions: [
          IconButton(
            tooltip: l10n.salesSearchTitle,
            onPressed: editable ? _search : null,
            icon: const Icon(Icons.search_rounded),
          ),
          if (state.lines.isNotEmpty && editable)
            IconButton(
              tooltip: l10n.salesClearCart,
              onPressed: _notifier.clear,
              icon: const Icon(Icons.remove_shopping_cart_outlined),
            ),
        ],
      ),
      bottomNavigationBar: state.lines.isEmpty || state.isLocked
          ? null
          : SaleTotalBar(
              total: cartTotalPreview(state.lines),
              submitting: state.phase == QuickSalePhase.submitting,
              onSubmit: state.canSubmit ? _notifier.submit : null,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OfflineBanner(),
          if (state.isLocked)
            _LockedSale(
              state: state,
              onRetry: _notifier.retry,
              onDiscard: _discard,
            )
          else
            Padding(
              padding: EdgeInsetsDirectional.all(spacing.md),
              child: BarcodeEntryField(
                enabled: editable,
                onSubmitted: _notifier.addBarcode,
                onCamera: _camera,
              ),
            ),
          if (state.isLookingUp || state.phase == QuickSalePhase.submitting)
            const LinearProgressIndicator(),
          if (banner != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                spacing.md,
                spacing.xs,
                spacing.md,
                spacing.xs,
              ),
              child: FormBanner(message: banner),
            ),
          Expanded(
            child: AsyncStateView<QuickSaleState>(
              value: AsyncData(state),
              isEmpty: (s) => s.lines.isEmpty,
              empty: state.isLocked
                  ? const SizedBox.shrink()
                  : EmptyState(
                      title: l10n.salesCartEmptyTitle,
                      body: l10n.salesCartEmptyBody,
                      action: EmptyStateAction(
                        label: l10n.salesSearchTitle,
                        onPressed: _search,
                      ),
                    ),
              data: (context, s) =>
                  _Cart(state: s, notifier: _notifier, onUnit: _pickUnit),
            ),
          ),
        ],
      ),
    );
  }

  /// The one message above the cart: a lookup failure, the line limit, a
  /// submit failure or lines to fix.
  String? _banner(AppLocalizations l10n, QuickSaleState state) {
    final lookup = state.lookupFailure;
    final failure = state.failure;
    if (lookup != null) {
      return lookup is NotFoundFailure &&
              lookup.code == ApiErrorCode.productNotFound
          ? l10n.salesBarcodeNotFound
          : failureMessage(l10n, lookup);
    }
    if (state.lineLimitReached) {
      return l10n.salesLineLimit(SaleRules.maxLines);
    }
    if (failure != null && !state.isLocked) {
      return failureMessage(l10n, failure);
    }
    if (state.lineErrors.isNotEmpty) {
      return l10n.salesFixLines;
    }
    return null;
  }
}

/// The cart lines and the note.
class _Cart extends StatefulWidget {
  const new({
    required this.state,
    required this.notifier,
    required this.onUnit,
  });

  final QuickSaleState state;
  final QuickSaleNotifier notifier;
  final ValueChanged<int> onUnit;

  @override
  State<_Cart> createState() => _CartState();
}

class _CartState extends State<_Cart> {
  late final TextEditingController _note = TextEditingController(
    text: widget.state.note,
  );

  @override
  void didUpdateWidget(_Cart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.note != _note.text) {
      _note.text = widget.state.note;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = widget.state;
    final notifier = widget.notifier;
    final enabled = state.isEditable;
    return ListView(
      padding: EdgeInsetsDirectional.only(bottom: spacing.xl),
      children: [
        for (final line in state.lines)
          CartLineTile(
            key: ValueKey(line.key),
            line: line,
            enabled: enabled,
            hasError:
                state.lineErrors.contains(line.key) ||
                state.lineMessages.containsKey(line.key),
            messages: state.lineMessages[line.key] ?? const [],
            onQuantity: (text) => notifier.setQuantity(line.key, text),
            onPrice: (text) => notifier.setPrice(line.key, text),
            onUnit: () => widget.onUnit(line.key),
            onRemove: () => notifier.removeLine(line.key),
          ),
        Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: TextField(
            controller: _note,
            enabled: enabled,
            onChanged: notifier.setNote,
            maxLength: SaleRules.noteMaxLength,
            decoration: InputDecoration(labelText: l10n.salesNoteLabel),
          ),
        ),
      ],
    );
  }
}

/// The cart of a sale whose outcome is unknown (design §6.8): only Retry
/// (same sale, never recorded twice) or Discard.
class _LockedSale extends StatelessWidget {
  const new({
    required this.state,
    required this.onRetry,
    required this.onDiscard,
  });

  final QuickSaleState state;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final failure = state.failure;
    final since = state.lockedSince;
    final language = Localizations.localeOf(context).languageCode;
    final sending = state.phase == QuickSalePhase.submitting;
    final total = state.lines.isEmpty ? null : cartTotalPreview(state.lines);
    return Padding(
      padding: EdgeInsetsDirectional.all(spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningSoft,
          borderRadius: BorderRadiusDirectional.circular(context.radii.md),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.sync_problem_rounded, color: colors.warning),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      l10n.salesLockedTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(l10n.salesLockedBody),
              Text(l10n.salesItemCount(state.lockedLineCount)),
              if (since != null)
                Text(
                  l10n.salesLockedSince(
                    ltrIsolate(DateFormatter.dateTime(since, language)),
                  ),
                ),
              if (total != null) MoneyText(total),
              if (failure != null)
                Text(
                  failureMessage(l10n, failure),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.muted),
                ),
              SizedBox(height: spacing.sm),
              Wrap(
                spacing: spacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: sending ? null : onDiscard,
                    child: Text(l10n.salesDiscard),
                  ),
                  FilledButton.icon(
                    onPressed: sending ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The units of a cart line's product; pops with the chosen unit id.
class _UnitSheet extends StatelessWidget {
  const new({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            l10n.salesChooseUnit,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final unit in line.units)
          ListTile(
            title: Text(unit.name),
            trailing: MoneyText(unit.sellPrice),
            selected: unit.id == line.unit.id,
            onTap: () => Navigator.of(context).pop(unit.id),
          ),
      ],
    );
  }
}
