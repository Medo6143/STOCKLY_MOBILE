import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/presentation/providers/subscription_notifier.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A soft warning on the dashboard once today's scans reach 80 % of the
/// quota (B2, plans-payments brief), with "Upgrade" opening the plans.
/// The dashboard shows it to the Owner only. It is a hint: while B2 loads,
/// fails or the shop is below 80 %, it takes no space.
class QuotaWarningCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(subscriptionProvider).value;
    if (summary == null || !summary.isNearQuota) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
      child: SurfaceCard(
        color: colors.warningSoft,
        level: 0,
        child: Row(
          children: [
            const LeadingBadge(
              icon: Icons.document_scanner_outlined,
              tone: PillTone.warning,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billingQuotaWarningTitle,
                    style: textTheme.titleMedium?.copyWith(color: colors.ink),
                  ),
                  Text(
                    l10n.billingScansToday(
                      summary.scansToday,
                      summary.effectiveDailyScanQuota,
                    ),
                    style: textTheme.bodySmall?.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
            SizedBox(width: spacing.xs),
            PressScale(
              child: FilledButton(
                onPressed: () => context.goNamed(RouteNames.plans),
                child: Text(l10n.billingUpgrade),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
