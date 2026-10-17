import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/stock_count_notifier.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/features/products/presentation/widgets/stock_product_header.dart';
import 'package:stockly/features/products/presentation/widgets/submit_button.dart';
import 'package:stockly/features/products/presentation/widgets/unit_picker.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The Owner's stock count (P10, design §11). States as the adjustment:
/// loading = the product preload (P2) or the submit spinner; empty = the
/// blank form; error = number issues under the field, other failures in
/// the banner; data = the form. The result reads "Count matches, nothing
/// changed" when `changed` is `false`, else the new quantity.
class StockCountScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = productDetailProvider(productId);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).stockCountTitle)),
      body: AsyncStateView<ProductDetail>(
        loading: const LoadingState(shape: LoadingShape.form),
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (context, product) => _CountForm(product: product),
      ),
    );
  }
}

class _CountForm extends ConsumerStatefulWidget {
  const new({required this.product});

  final ProductDetail product;

  @override
  ConsumerState<_CountForm> createState() => _CountFormState();
}

class _CountFormState extends ConsumerState<_CountForm> {
  final TextEditingController _counted = TextEditingController();
  String? _unitId;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(stockCountProvider(widget.product.id).notifier)
      .submit(countedQuantity: _counted.text, unitId: _unitId);

  String _resultText(AppLocalizations l10n, StockCountResult result) =>
      result.changed
      ? l10n.stockCountChanged(
          l10n.quantityWithUnit(
            ltrIsolate(DecimalFormatter.formatQuantity(result.quantity)),
            widget.product.baseUnit.name,
          ),
        )
      : l10n.stockCountUnchanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final product = widget.product;
    final form = ref.watch(stockCountProvider(product.id));
    final errors = form.errors;
    final enabled = !form.isSubmitting;
    final banner = errors.banner;
    final result = form.result;
    final gap = SizedBox(height: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        if (banner != null) ...[
          FormBanner(message: failureMessage(l10n, banner)),
          gap,
        ],
        if (result != null) ...[
          Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.mintSoft,
                borderRadius: context.radii.circular(context.radii.md),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.all(spacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: colors.ink),
                    SizedBox(width: spacing.xs),
                    Expanded(child: Text(_resultText(l10n, result))),
                  ],
                ),
              ),
            ),
          ),
          gap,
        ],
        StockProductHeader(product: product),
        gap,
        SectionCard(
          children: [
            UnitPicker(
              units: product.units,
              value: _unitId,
              enabled: enabled,
              onChanged: (value) => setState(() => _unitId = value),
              errorText: productFieldError(
                l10n,
                ProductField.stockUnit,
                errors,
              ),
            ),
            DecimalField(
              controller: _counted,
              label: l10n.stockCountQuantity,
              enabled: enabled,
              textInputAction: TextInputAction.done,
              errorText: productFieldError(
                l10n,
                ProductField.countedQuantity,
                errors,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        SubmitButton(
          label: l10n.stockCountSubmit,
          isBusy: form.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
