import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/sales/presentation/providers/sale_product_search_notifier.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Searches the catalogue (P1) for a product to sell; pops with the
/// picked [ProductListItem]. States: loading = the search; empty = "No
/// products match"; error = the failure with retry; data = the matches.
class SaleProductSearchSheet extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SaleProductSearchSheet> createState() =>
      _SaleProductSearchSheetState();
}

class _SaleProductSearchSheetState
    extends ConsumerState<SaleProductSearchSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = saleProductSearchProvider(_query);
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
                l10n.salesSearchTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.all(spacing.md),
              child: TextField(
                controller: _search,
                onChanged: _onChanged,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.productPickerSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: AsyncStateView<List<ProductListItem>>(
                value: ref.watch(provider),
                isEmpty: (items) => items.isEmpty,
                empty: EmptyState(
                  title: l10n.productPickerEmptyTitle,
                  body: l10n.salesSearchEmptyBody,
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
                      onTap: () => Navigator.of(context).pop(item),
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
