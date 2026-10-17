import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/presentation/providers/sale_detail_notifier.dart';
import 'package:stockly/features/sales/presentation/widgets/negative_stock_warning.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_item_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One sale (S3, design §11). States: loading = S3; empty = not
/// applicable (a sale has lines); error = `Sale.NotFound` (also another
/// shop's sale) with back, or retry; data = negative-stock warnings, the
/// lines, the total and the note. [alreadyRecorded] adds "This sale was
/// already recorded" after a retry that found the earlier sale.
class SaleDetailScreen extends ConsumerWidget {
  const new({required this.saleId, this.alreadyRecorded = false, super.key});

  final String saleId;
  final bool alreadyRecorded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = saleDetailProvider(saleId);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesDetailTitle)),
      body: AsyncStateView<Sale>(
        loading: const LoadingState(shape: LoadingShape.detail),
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (context, sale) =>
            _SaleView(sale: sale, alreadyRecorded: alreadyRecorded),
      ),
    );
  }
}

class _SaleView extends StatelessWidget {
  const new({required this.sale, required this.alreadyRecorded});

  final Sale sale;
  final bool alreadyRecorded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final language = Localizations.localeOf(context).languageCode;
    final note = sale.note;
    final gutter = EdgeInsetsDirectional.symmetric(horizontal: spacing.md);
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
      children: [
        if (alreadyRecorded)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing.md,
              0,
              spacing.md,
              spacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colors.mint),
                SizedBox(width: spacing.xs),
                Expanded(child: Text(l10n.salesAlreadyRecorded)),
              ],
            ),
          ),
        for (final product in sale.negativeStockProducts)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing.md,
              0,
              spacing.md,
              spacing.xs,
            ),
            child: NegativeStockWarning(productName: product),
          ),
        Padding(
          padding: gutter,
          child: SurfaceCard(
            level: 2,
            radius: context.radii.xxl,
            padding: EdgeInsetsDirectional.all(spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LeadingBadge(icon: Icons.receipt_rounded),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        l10n.salesTotalLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      ltrIsolate(
                        DateFormatter.dateTime(sale.createdAt, language),
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                MoneyText(
                  sale.totalAmount,
                  style: context.typo.numberLarge.copyWith(color: colors.ink),
                ),
                if (sale.priceOverridden) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.salesHasOverride,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.warning),
                  ),
                ],
                if (note != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(l10n.salesNoteValue(note)),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.lg),
        Padding(
          padding: gutter,
          child: Text(
            l10n.salesLinesHeader,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final item in sale.items) SaleItemTile(item: item),
      ],
    );
  }
}
