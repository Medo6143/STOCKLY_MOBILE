import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_state.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The cart of a sale whose outcome is unknown (design §6.8): only Retry
/// (same sale, never recorded twice) or Discard.
class LockedSaleCard extends StatelessWidget {
  const new({
    required this.state,
    required this.onRetry,
    required this.onDiscard,
    super.key,
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
