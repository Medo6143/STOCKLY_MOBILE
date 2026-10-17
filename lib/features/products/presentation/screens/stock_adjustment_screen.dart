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
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/stock_adjustment_notifier.dart';
import 'package:stockly/features/products/presentation/providers/stock_change_states.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/features/products/presentation/widgets/stock_product_header.dart';
import 'package:stockly/features/products/presentation/widgets/submit_button.dart';
import 'package:stockly/features/products/presentation/widgets/unit_picker.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The Owner's manual stock correction (P9, design §11): a signed change
/// in a unit, with a required reason. States: loading = the product
/// preload (P2) or the submit spinner; empty = the blank form; error =
/// zero change and missing reason under their fields, other failures
/// (precision, not found, `Auth.Forbidden`) in the banner; data = the
/// form. Success shows the new balance and returns to the product.
class StockAdjustmentScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = productDetailProvider(productId);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).stockAdjustTitle),
      ),
      body: AsyncStateView<ProductDetail>(
        loading: const LoadingState(shape: LoadingShape.form),
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (context, product) => _AdjustmentForm(product: product),
      ),
    );
  }
}

class _AdjustmentForm extends ConsumerStatefulWidget {
  const new({required this.product});

  final ProductDetail product;

  @override
  ConsumerState<_AdjustmentForm> createState() => _AdjustmentFormState();
}

class _AdjustmentFormState extends ConsumerState<_AdjustmentForm> {
  final TextEditingController _change = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _unitId;

  @override
  void dispose() {
    _change.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(stockAdjustmentProvider(widget.product.id).notifier)
      .submit(quantityChange: _change.text, unitId: _unitId, note: _note.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final product = widget.product;
    final base = product.baseUnit;
    final provider = stockAdjustmentProvider(product.id);
    ref.listen<StockAdjustmentState>(provider, (previous, next) {
      final movement = next.movement;
      if (movement != null && previous?.movement == null) {
        showMessageSnackBar(
          context,
          l10n.stockAdjustDone(
            l10n.quantityWithUnit(
              ltrIsolate(
                DecimalFormatter.formatQuantity(movement.balanceAfter),
              ),
              base.name,
            ),
          ),
        );
        Navigator.of(context).maybePop();
      }
    });
    final form = ref.watch(provider);
    final errors = form.errors;
    final enabled = !form.isSubmitting;
    final banner = errors.banner;
    final gap = SizedBox(height: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        if (banner != null) ...[
          FormBanner(message: failureMessage(l10n, banner)),
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
              controller: _change,
              label: l10n.stockAdjustChange,
              enabled: enabled,
              signed: true,
              errorText: productFieldError(
                l10n,
                ProductField.quantityChange,
                errors,
              ),
            ),
            TextField(
              controller: _note,
              enabled: enabled,
              maxLines: null,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.stockAdjustNote,
                hintText: l10n.stockAdjustNoteHint,
                errorText: productFieldError(l10n, ProductField.note, errors),
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        SubmitButton(
          label: l10n.stockAdjustSubmit,
          isBusy: form.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
