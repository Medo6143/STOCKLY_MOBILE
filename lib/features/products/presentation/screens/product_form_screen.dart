import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/owner_only.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_state.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/features/products/presentation/widgets/submit_button.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Create (P3) or edit (P4) a product (design §11). States: loading = the
/// edit preload (P2) or the submit spinner; empty = the blank create form,
/// or "archived products cannot be edited"; error = field errors under
/// their fields, other failures in the banner, a failed preload with retry;
/// data = the filled form. Only the Owner sees the opening quantity.
class ProductFormScreen extends ConsumerWidget {
  const new({this.productId, super.key});

  /// `null` creates a product.
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final productId = this.productId;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          productId == null
              ? l10n.productsFormCreateTitle
              : l10n.productsFormEditTitle,
        ),
      ),
      body: productId == null
          ? const _ProductForm(product: null)
          : AsyncStateView<ProductDetail>(
              value: ref.watch(productDetailProvider(productId)),
              onRetry: () => ref.invalidate(productDetailProvider(productId)),
              isEmpty: (product) => product.isArchived,
              empty: EmptyState(
                title: l10n.productsFormArchivedTitle,
                body: l10n.productsFormArchivedBody,
              ),
              data: (context, product) => _ProductForm(product: product),
            ),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const new({required this.product});

  /// `null` for create.
  final ProductDetail? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _baseUnitName;
  late final TextEditingController _costPrice;
  late final TextEditingController _sellPrice;
  late final TextEditingController _threshold;
  late final TextEditingController _opening;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _barcode = TextEditingController(text: product?.barcode);
    _category = TextEditingController(text: product?.category);
    _baseUnitName = TextEditingController();
    _costPrice = TextEditingController(text: _money(product?.costPrice));
    _sellPrice = TextEditingController();
    _threshold = TextEditingController(
      text: _quantity(product?.lowStockThreshold),
    );
    _opening = TextEditingController();
  }

  /// The value as the user would type it: exact, without grouping.
  static String? _money(Money? value) => value?.toApi();

  static String? _quantity(Quantity? value) => value?.value.toString();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _barcode,
      _category,
      _baseUnitName,
      _costPrice,
      _sellPrice,
      _threshold,
      _opening,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _productId => widget.product?.id;

  void _submit() => ref
      .read(productFormProvider(_productId).notifier)
      .submit(
        ProductFormInput(
          name: _name.text,
          barcode: _barcode.text,
          category: _category.text,
          costPrice: _costPrice.text,
          lowStockThreshold: _threshold.text,
          baseUnitName: _baseUnitName.text,
          baseUnitSellPrice: _sellPrice.text,
          openingQuantity: _opening.text,
        ),
      );

  void _onSaved(ProductDetail saved) {
    showMessageSnackBar(context, AppLocalizations.of(context).productsSaved);
    if (_productId == null) {
      context.goNamed(
        RouteNames.productDetail,
        pathParameters: {RoutePaths.productIdParameter: saved.id},
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = productFormProvider(_productId);
    ref.listen<ProductFormState>(provider, (previous, next) {
      final saved = next.saved;
      if (saved != null && previous?.saved == null) {
        _onSaved(saved);
      }
    });
    final form = ref.watch(provider);
    final errors = form.errors;
    final enabled = !form.isSubmitting;
    final isCreate = widget.product == null;
    String? errorOf(ProductField field) =>
        productFieldError(l10n, field, errors);
    Widget text(
      TextEditingController controller,
      String label,
      ProductField field, {
      bool ltr = false,
    }) => TextField(
      controller: controller,
      enabled: enabled,
      textDirection: ltr ? TextDirection.ltr : null,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorOf(field),
        errorMaxLines: 3,
      ),
    );
    Widget number(
      TextEditingController controller,
      String label,
      ProductField field, {
      String? helper,
    }) => DecimalField(
      controller: controller,
      label: label,
      enabled: enabled,
      errorText: errorOf(field),
      helperText: helper,
    );
    final banner = errors.banner;
    final gap = SizedBox(height: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        if (banner != null) ...[
          FormBanner(message: failureMessage(l10n, banner)),
          gap,
        ],
        if (!isCreate) ...[
          Text(
            l10n.productsFormEditHint,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.muted),
          ),
          gap,
        ],
        text(_name, l10n.productsFormName, ProductField.name),
        gap,
        if (isCreate) ...[
          text(
            _baseUnitName,
            l10n.productsFormBaseUnitName,
            ProductField.baseUnitName,
          ),
          gap,
        ],
        number(_costPrice, l10n.productsFormCostPrice, ProductField.costPrice),
        gap,
        if (isCreate) ...[
          number(
            _sellPrice,
            l10n.productsFormSellPrice,
            ProductField.baseUnitSellPrice,
          ),
          gap,
        ],
        number(
          _threshold,
          isCreate
              ? l10n.productsFormThreshold
              : l10n.productsFormThresholdRequired,
          ProductField.lowStockThreshold,
        ),
        gap,
        if (isCreate)
          OwnerOnly(
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacing.md),
              child: number(
                _opening,
                l10n.productsFormOpeningQuantity,
                ProductField.openingQuantity,
                helper: l10n.productsFormOpeningHint,
              ),
            ),
          ),
        text(
          _barcode,
          l10n.productsFormBarcode,
          ProductField.barcode,
          ltr: true,
        ),
        gap,
        text(_category, l10n.productsFormCategory, ProductField.category),
        SizedBox(height: spacing.xl),
        SubmitButton(
          label: isCreate
              ? l10n.productsFormSubmitCreate
              : l10n.productsFormSubmitEdit,
          isBusy: form.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
