import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/fake_backend/panel/fake_payment_panel.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/owner_only.dart';
import 'package:stockly/core/widgets/primary_button.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/core/widgets/state_illustration.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/success_check.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/presentation/providers/payment_status_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/payment_status_state.dart';
import 'package:stockly/features/billing/presentation/widgets/billing_labels.dart';
import 'package:stockly/features/billing/presentation/widgets/checkout_sheet.dart';
import 'package:stockly/features/billing/presentation/widgets/kiosk_reference_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One payment (B4, plans-payments brief), polled every 3 s while it is
/// `Pending` and the screen is visible; the app coming back to the
/// foreground asks again. Only the server's status decides, never the
/// browser redirect. States: loading = a detail skeleton until the first
/// answer; empty = not applicable; error = the first answer failed
/// (`Payment.NotFound`, network) with retry; data = by status: pending
/// card or wallet (open the payment page again), pending kiosk (the
/// reference to pay), paid (the success check), failed or expired (the
/// reason as secondary text, "Try again" for the Owner). The Owner can
/// cancel a pending payment.
class PaymentStatusScreen extends ConsumerStatefulWidget {
  const new({required this.paymentId, super.key});

  final String paymentId;

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  late final AppLifecycleListener _lifecycle;

  PaymentStatusNotifier get _notifier =>
      ref.read(paymentStatusProvider(widget.paymentId).notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () => _notifier.pause(),
      onResume: () => _notifier.refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = paymentStatusProvider(widget.paymentId);
    final state = ref.watch(provider);
    ref
      ..listen(provider.select((s) => s.cancelFailure), (_, failure) {
        if (failure != null) {
          showFailureSnackBar(context, failure);
        }
      })
      ..listen(provider.select((s) => s.pageNotOpened), (_, notOpened) {
        if (notOpened) {
          showMessageSnackBar(context, l10n.billingPaymentPageNotOpened);
        }
      });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingPaymentTitle)),
      body: AsyncStateView<Payment>(
        value: state.view,
        loading: const LoadingState(shape: LoadingShape.detail),
        onRetry: _notifier.refresh,
        data: (context, payment) =>
            _PaymentBody(payment: payment, state: state, notifier: _notifier),
      ),
    );
  }
}

class _PaymentBody extends StatelessWidget {
  const new({
    required this.payment,
    required this.state,
    required this.notifier,
  });

  final Payment payment;
  final PaymentStatusState state;
  final PaymentStatusNotifier notifier;

  Future<void> _tryAgain(BuildContext context) async {
    final paymentId = await showCheckoutSheet(
      context,
      planId: payment.planId,
      planName: payment.planName,
      amount: payment.amount,
    );
    if (paymentId != null && context.mounted) {
      context.pushReplacementNamed(
        RouteNames.paymentStatus,
        pathParameters: {RoutePaths.paymentIdParameter: paymentId},
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.billingCancelConfirmTitle),
        content: Text(l10n.billingCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.billingKeepPayment),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.billingCancelPayment),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await notifier.cancel();
    }
  }

  Future<void> _openFakePanel(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => FakePaymentPanel(
          paymentId: payment.id,
          onSettled: notifier.refresh,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.muted);
    final pending = payment.isPending;
    final sections = <Widget>[
      _PaymentSummary(payment: payment),
      switch (payment.status) {
        PaymentStatus.pending when payment.method == PaymentMethod.kiosk =>
          KioskReferenceCard(payment: payment),
        PaymentStatus.pending => _Outcome(
          illustration: StateIllustration(
            icon: Icons.hourglass_top_rounded,
            color: colors.warning,
            background: colors.warningSoft,
          ),
          title: l10n.billingWaitingTitle,
          body: l10n.billingWaitingBody,
          action: payment.openableCheckoutUrl == null
              ? null
              : OutlinedButton.icon(
                  onPressed: notifier.openCheckout,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.billingOpenPaymentPage),
                ),
        ),
        PaymentStatus.paid => _Outcome(
          illustration: SuccessCheck(
            size: spacing.huge * 2,
            semanticLabel: l10n.billingPaidTitle,
          ),
          title: l10n.billingPaidTitle,
          body: l10n.billingPaidBody(payment.planName),
          action: PrimaryButton(
            label: l10n.billingDone,
            onPressed: () => context.goNamed(RouteNames.profile),
          ),
        ),
        PaymentStatus.failed || PaymentStatus.expired => _Outcome(
          illustration: StateIllustration(
            icon: payment.status == PaymentStatus.failed
                ? Icons.error_outline_rounded
                : Icons.timer_off_outlined,
            color: payment.status == PaymentStatus.failed
                ? colors.danger
                : colors.muted,
            background: payment.status == PaymentStatus.failed
                ? colors.dangerSoft
                : colors.line,
          ),
          title: payment.status == PaymentStatus.failed
              ? l10n.billingFailedTitle
              : l10n.billingExpiredTitle,
          body: payment.status == PaymentStatus.failed
              ? l10n.billingFailedBody
              : l10n.billingExpiredBody,
          secondary: payment.failureReason,
          action: OwnerOnly(
            child: PrimaryButton(
              label: l10n.commonRetry,
              onPressed: () => _tryAgain(context),
            ),
          ),
        ),
      },
      if (pending && state.failure != null)
        Text(l10n.billingPollFailed, style: muted, textAlign: TextAlign.center),
      if (state.waitingWithoutPolling)
        Column(
          children: [
            Text(
              l10n.billingStillWaiting,
              style: muted,
              textAlign: TextAlign.center,
            ),
            TextButton.icon(
              onPressed: notifier.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.billingRefresh),
            ),
          ],
        ),
      if (pending)
        OwnerOnly(
          child: TextButton.icon(
            onPressed: state.cancelling ? null : () => _confirmCancel(context),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            icon: const Icon(Icons.close_rounded),
            label: Text(l10n.billingCancelPayment),
          ),
        ),
      if (kFakeBackendEnabled && pending)
        TextButton.icon(
          onPressed: () => _openFakePanel(context),
          icon: const Icon(Icons.bug_report_outlined),
          label: Text(l10n.fakePanelPaymentTitle),
        ),
    ];
    return EntranceScope(
      child: ListView(
        padding: EdgeInsetsDirectional.all(spacing.md),
        children: [
          for (final (index, section) in sections.indexed)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
              child: Entrance(index: index, child: section),
            ),
        ],
      ),
    );
  }
}

/// Plan, amount, method, date and status of the payment.
class _PaymentSummary extends StatelessWidget {
  const new({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    return SurfaceCard(
      level: 2,
      radius: context.radii.xl,
      padding: EdgeInsetsDirectional.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LeadingBadge(
                icon: paymentMethodIcon(payment.method),
                tone: paymentStatusTone(payment.status),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(payment.planName, style: textTheme.titleLarge),
              ),
              StatusPill(
                label: paymentStatusLabel(l10n, payment.status),
                tone: paymentStatusTone(payment.status),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          MoneyText(
            payment.amount,
            style: context.typo.numberLarge.copyWith(color: colors.ink),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            l10n.billingPaymentSubtitle(
              paymentMethodLabel(l10n, payment.method),
              ltrIsolate(DateFormatter.dateTime(payment.createdAt, language)),
            ),
            style: textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// The outcome of a payment: an illustration, a title, a body, the
/// provider's text when there is one, and an action.
class _Outcome extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    required this.body,
    this.secondary,
    this.action,
  });

  final Widget illustration;
  final String title;
  final String body;
  final String? secondary;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final secondary = this.secondary;
    final action = this.action;
    return SurfaceCard(
      padding: EdgeInsetsDirectional.all(spacing.lg),
      child: Column(
        children: [
          illustration,
          SizedBox(height: spacing.md),
          Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
          SizedBox(height: spacing.xs),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(color: colors.muted),
            textAlign: TextAlign.center,
          ),
          if (secondary != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              secondary,
              style: textTheme.bodySmall?.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[SizedBox(height: spacing.lg), action],
        ],
      ),
    );
  }
}
