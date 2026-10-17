import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/unit_form_notifier.dart';
import 'package:stockly/features/products/presentation/providers/unit_form_state.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/features/products/presentation/widgets/submit_button.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Add (P6), edit (P7) or delete (P8) a unit (design §11). States: loading
/// = the product preload (P2) or the save/delete spinner; empty = the
/// blank add form, or "units of an archived product cannot be changed";
/// error = field errors (duplicate name or barcode), other failures in the
/// banner, an unknown unit as "not found"; data = the form. The base unit
/// keeps factor 1 and cannot be deleted.
class UnitFormScreen extends ConsumerWidget {
  const new({required this.productId, this.unitId, super.key});

  final String productId;

  /// `null` adds a unit.
  final String? unitId;

  /// A unit id that is not on the product (contract `ProductUnit.NotFound`).
  static const NotFoundFailure _unitNotFound = NotFoundFailure(
    ApiErrorCode.productUnitNotFound,
    ApiProblemInfo(status: HttpStatus.notFound),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unitId = this.unitId;
    final provider = productDetailProvider(productId);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          unitId == null ? l10n.unitsFormCreateTitle : l10n.unitsFormEditTitle,
        ),
      ),
      body: AsyncStateView<ProductDetail>(
        loading: const LoadingState(shape: LoadingShape.form),
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        isEmpty: (product) => product.isArchived,
        empty: EmptyState(
          title: l10n.unitsArchivedTitle,
          body: l10n.productsFormArchivedBody,
        ),
        data: (context, product) {
          final unit = unitId == null ? null : product.unitById(unitId);
          if (unitId != null && unit == null) {
            return const ErrorState(failure: _unitNotFound);
          }
          return _UnitForm(product: product, unit: unit);
        },
      ),
    );
  }
}

class _UnitForm extends ConsumerStatefulWidget {
  const new({required this.product, required this.unit});

  final ProductDetail product;

  /// `null` for a new unit.
  final ProductUnit? unit;

  @override
  ConsumerState<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends ConsumerState<_UnitForm> {
  late final TextEditingController _name;
  late final TextEditingController _factor;
  late final TextEditingController _sellPrice;
  late final TextEditingController _barcode;

  @override
  void initState() {
    super.initState();
    final unit = widget.unit;
    _name = TextEditingController(text: unit?.name);
    _factor = TextEditingController(text: unit?.factor.value.toString());
    _sellPrice = TextEditingController(text: unit?.sellPrice.toApi());
    _barcode = TextEditingController(text: unit?.barcode);
  }

  @override
  void dispose() {
    _name.dispose();
    _factor.dispose();
    _sellPrice.dispose();
    _barcode.dispose();
    super.dispose();
  }

  UnitFormArgs get _args =>
      UnitFormArgs(productId: widget.product.id, unitId: widget.unit?.id);

  void _save() => ref
      .read(unitFormProvider(_args).notifier)
      .save(
        name: _name.text,
        factor: _factor.text,
        sellPrice: _sellPrice.text,
        barcode: _barcode.text,
      );

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unitsDeleteDialogTitle),
        content: Text(l10n.unitsDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.unitsDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(unitFormProvider(_args).notifier).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = unitFormProvider(_args);
    ref.listen<UnitFormState>(provider, (previous, next) {
      final outcome = next.outcome;
      if (outcome != null && previous?.outcome == null) {
        showMessageSnackBar(context, switch (outcome) {
          UnitFormOutcome.saved => l10n.unitsSaved,
          UnitFormOutcome.deleted => l10n.unitsDeleted,
        });
        Navigator.of(context).maybePop();
      }
    });
    final form = ref.watch(provider);
    final errors = form.errors;
    final enabled = !form.isBusy;
    final unit = widget.unit;
    final isBase = unit?.isBase ?? false;
    final banner = errors.banner;
    final gap = SizedBox(height: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        if (banner != null) ...[
          FormBanner(message: failureMessage(l10n, banner)),
          gap,
        ],
        SectionCard(
          title: widget.product.name,
          icon: Icons.layers_outlined,
          children: [
            TextField(
              controller: _name,
              enabled: enabled,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.unitsFormName,
                errorText: productFieldError(
                  l10n,
                  ProductField.unitName,
                  errors,
                ),
                errorMaxLines: 3,
              ),
            ),
            DecimalField(
              controller: _factor,
              label: l10n.unitsFormFactor(widget.product.baseUnit.name),
              enabled: enabled,
              readOnly: isBase,
              helperText: isBase ? l10n.unitsFormFactorBaseFixed : null,
              errorText: productFieldError(
                l10n,
                ProductField.unitFactor,
                errors,
              ),
            ),
            DecimalField(
              controller: _sellPrice,
              label: l10n.unitsFormSellPrice,
              enabled: enabled,
              errorText: productFieldError(
                l10n,
                ProductField.unitSellPrice,
                errors,
              ),
            ),
            TextField(
              controller: _barcode,
              enabled: enabled,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.productsFormBarcode,
                errorText: productFieldError(
                  l10n,
                  ProductField.unitBarcode,
                  errors,
                ),
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        SubmitButton(
          label: l10n.unitsFormSubmit,
          isBusy: form.isSubmitting,
          onPressed: enabled ? _save : null,
        ),
        if (unit != null && !isBase) ...[
          SizedBox(height: spacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.danger,
            ),
            onPressed: enabled ? _delete : null,
            icon: form.isDeleting
                ? SizedBox.square(
                    dimension: spacing.md,
                    child: CircularProgressIndicator(
                      strokeWidth: spacing.xxs / 2,
                      semanticsLabel: l10n.commonLoading,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.unitsDelete),
          ),
        ],
      ],
    );
  }
}
