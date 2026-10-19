import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/presentation/widgets/billing_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One plan of the plans screen: name, price, daily scans and members. The
/// current plan is marked; [onChoose] (`null` hides it) starts paying.
class PlanOptionCard extends StatelessWidget {
  const new({required this.plan, this.onChoose, super.key});

  final BillingPlan plan;

  /// Shown as "Choose" for the Owner on a paid plan that is not current.
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.muted);
    final onChoose = this.onChoose;
    Widget fact(IconData icon, String text) => Padding(
      padding: EdgeInsetsDirectional.only(top: spacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: spacing.md, color: colors.muted),
          SizedBox(width: spacing.xs),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );
    return SurfaceCard(
      level: plan.isCurrent ? 2 : 1,
      radius: context.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LeadingBadge(
                icon: plan.isFree
                    ? Icons.eco_outlined
                    : Icons.workspace_premium_rounded,
                tone: plan.isCurrent ? PillTone.mint : PillTone.neutral,
              ),
              SizedBox(width: spacing.sm),
              Expanded(child: Text(plan.name, style: textTheme.titleLarge)),
              if (plan.isCurrent)
                StatusPill(
                  label: l10n.billingCurrentPlan,
                  tone: PillTone.mint,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            planPriceLabel(l10n, plan),
            style: context.typo.numberMedium.copyWith(color: colors.ink),
          ),
          SizedBox(height: spacing.xs),
          fact(
            Icons.document_scanner_outlined,
            l10n.billingPlanQuota(plan.dailyScanQuota),
          ),
          fact(Icons.group_outlined, l10n.billingPlanMembers(plan.maxMembers)),
          if (onChoose != null) ...[
            SizedBox(height: spacing.md),
            PressScale(
              child: FilledButton(
                onPressed: onChoose,
                child: Text(l10n.billingChoose),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
