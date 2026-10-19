import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/skeleton_box.dart';
import 'package:stockly/core/widgets/skeleton_shimmer.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/presentation/providers/subscription_notifier.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// "Your plan" on the profile (B2, plans-payments brief): plan name and
/// price, today's scans against the quota with a progress bar, members
/// against the limit, the renewal date and a banner while a payment is
/// pending. Tapping opens the plans. States: loading = a skeleton card;
/// empty = not applicable (every shop has a plan); error = the message
/// with retry; data = the plan.
class YourPlanCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(subscriptionProvider);
    return switch (value) {
      AsyncValue(:final value?) => _PlanContent(summary: value),
      AsyncError() => _PlanError(
        onRetry: () => ref.invalidate(subscriptionProvider),
      ),
      _ => const _PlanSkeleton(),
    };
  }
}

class _PlanContent extends StatelessWidget {
  const new({required this.summary});

  final SubscriptionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.muted);
    final plan = summary.plan;
    final endsOn = summary.endsOn;
    final pending = summary.pendingPayment;
    final near = summary.isNearQuota;
    return SurfaceCard(
      onTap: () => context.pushNamed(RouteNames.plans),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const LeadingBadge(icon: Icons.workspace_premium_rounded),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.billingYourPlan,
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                    Text(plan.name, style: textTheme.titleLarge),
                    Text(
                      plan.isFree
                          ? l10n.billingFree
                          : l10n.billingPricePerMonth(
                              l10n.moneyAmount(
                                ltrIsolate(
                                  DecimalFormatter.formatMoney(
                                    plan.monthlyPrice,
                                  ),
                                ),
                              ),
                            ),
                      style: muted,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
          SizedBox(height: spacing.md),
          Text(
            l10n.billingScansToday(
              summary.scansToday,
              summary.effectiveDailyScanQuota,
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: near ? colors.warning : colors.ink,
            ),
          ),
          SizedBox(height: spacing.xxs),
          ClipRRect(
            borderRadius: context.radii.circular(context.radii.pill),
            child: LinearProgressIndicator(
              value: summary.scanUsage,
              minHeight: spacing.xs,
              backgroundColor: colors.line,
              color: near ? colors.warning : colors.mint,
              semanticsLabel: l10n.billingScansToday(
                summary.scansToday,
                summary.effectiveDailyScanQuota,
              ),
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            l10n.billingMembers(summary.memberCount, plan.maxMembers),
            style: muted,
          ),
          if (endsOn != null)
            Text(
              l10n.billingRenewsOn(
                ltrIsolate(DateFormatter.date(endsOn, language)),
              ),
              style: muted,
            ),
          if (pending != null) ...[
            SizedBox(height: spacing.sm),
            _PendingBanner(payment: pending),
          ],
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const new({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    return SurfaceCard(
      level: 0,
      color: colors.warningSoft,
      onTap: () => context.pushNamed(
        RouteNames.paymentStatus,
        pathParameters: {RoutePaths.paymentIdParameter: payment.id},
      ),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: colors.warning),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              l10n.billingPendingBanner,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.ink),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.warning),
        ],
      ),
    );
  }
}

class _PlanError extends StatelessWidget {
  const new({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    return SurfaceCard(
      child: Row(
        children: [
          const LeadingBadge(
            icon: Icons.error_outline_rounded,
            tone: PillTone.danger,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              l10n.billingPlanError,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.ink),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

class _PlanSkeleton extends StatelessWidget {
  const new();

  static const double _title = 0.5;
  static const double _line = 0.7;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Semantics(
      label: AppLocalizations.of(context).commonLoading,
      container: true,
      child: SkeletonShimmer(
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(height: spacing.lg, widthFactor: _title),
              SizedBox(height: spacing.sm),
              SkeletonBox(height: spacing.xs),
              SizedBox(height: spacing.sm),
              SkeletonBox(height: spacing.sm, widthFactor: _line),
            ],
          ),
        ),
      ),
    );
  }
}
