import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/invoices/presentation/providers/product_picker_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// What the picker returns: a product of the catalogue, or a request to
/// describe a new product.
sealed class ProductPickerResult {
  const new();
}

final class ProductPicked extends ProductPickerResult {
  const new(this.product);

  final ProductListItem product;
}

final class NewProductRequested extends ProductPickerResult {
  const new();
}

/// Searches the catalogue (P1) for the line editor (design §11). States:
/// loading = the search; empty = "No products match" with "Create new
/// product"; error = the failure inline with retry; data = the matches.
class ProductPickerSheet extends ConsumerStatefulWidget {
  const new({this.initialSearch = '', super.key});

  /// Usually the line's raw name.
  final String initialSearch;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialSearch,
  );
  late String _query = widget.initialSearch.trim();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      context.durations.searchDebounce,
      () => setState(() => _query = value.trim()),
    );
  }

  void _close(ProductPickerResult result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = productPickerProvider(_query);
    final createNew = TextButton.icon(
      onPressed: () => _close(const NewProductRequested()),
      icon: const Icon(Icons.add_rounded),
      label: Text(l10n.productPickerCreateNew),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: spacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
              child: Text(
                l10n.productPickerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.all(spacing.md),
              child: TextField(
                controller: _search,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.productPickerSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: createNew,
            ),
            Expanded(
              child: AsyncStateView<List<ProductListItem>>(
                value: ref.watch(provider),
                isEmpty: (items) => items.isEmpty,
                empty: EmptyState(
                  title: l10n.productPickerEmptyTitle,
                  body: l10n.productPickerEmptyBody,
                  action: EmptyStateAction(
                    label: l10n.productPickerCreateNew,
                    onPressed: () => _close(const NewProductRequested()),
                  ),
                ),
                onRetry: () => ref.invalidate(provider),
                data: (context, items) => ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      trailing: QuantityText(
                        item.quantity,
                        unit: item.baseUnit.name,
                        isLow: item.isLowStock,
                      ),
                      onTap: () => _close(ProductPicked(item)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
