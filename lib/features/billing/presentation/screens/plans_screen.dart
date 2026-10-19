import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/presentation/providers/plans_notifier.dart';
import 'package:stockly/features/billing/presentation/widgets/checkout_sheet.dart';
import 'package:stockly/features/billing/presentation/widgets/plan_option_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The plans (B1, plans-payments brief), free first, the current one
/// marked. The Owner gets "Choose" on paid plans that are not current,
/// which opens the checkout; Staff see the plans read-only with a note to
/// ask the owner. States: loading = card skeletons; empty = "No plans
/// yet"; error = retry; data = the plan cards. Pull to refresh.
class PlansScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(plansProvider);
      await ref.read(plansProvider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  Future<void> _choose(BuildContext context, BillingPlan plan) async {
    final paymentId = await showCheckoutSheet(
      context,
      planId: plan.id,
      planName: plan.name,
      amount: plan.monthlyPrice,
    );
    if (paymentId != null && context.mounted) {
      await context.pushNamed(
        RouteNames.paymentStatus,
        pathParameters: {RoutePaths.paymentIdParameter: paymentId},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final isOwner = ref.watch(isOwnerProvider);
    ref.listen(plansProvider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billingPlansTitle),
        actions: [
          IconButton(
            tooltip: l10n.billingPaymentHistory,
            onPressed: () => context.pushNamed(RouteNames.paymentHistory),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: AsyncStateView<List<BillingPlan>>(
        value: ref.watch(plansProvider),
        onRetry: () => ref.invalidate(plansProvider),
        isEmpty: (plans) => plans.isEmpty,
        empty: EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: l10n.billingPlansEmptyTitle,
          body: l10n.billingPlansEmptyBody,
        ),
        data: (context, plans) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: EntranceScope(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsetsDirectional.all(spacing.md),
              children: [
                if (!isOwner)
                  Padding(
                    padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
                    child: Entrance(
                      child: _StaffNote(text: l10n.billingStaffNote),
                    ),
                  ),
                for (final (index, plan) in plans.indexed)
                  Padding(
                    padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
                    child: Entrance(
                      index: index + 1,
                      child: PlanOptionCard(
                        plan: plan,
                        onChoose: isOwner && plan.canCheckOut
                            ? () => _choose(context, plan)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffNote extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    return SurfaceCard(
      level: 0,
      color: colors.warningSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.warning),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
