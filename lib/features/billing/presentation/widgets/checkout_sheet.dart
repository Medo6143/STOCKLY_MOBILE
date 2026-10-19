import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/primary_button.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/presentation/providers/checkout_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/checkout_state.dart';
import 'package:stockly/features/billing/presentation/widgets/billing_labels.dart';
import 'package:stockly/features/billing/presentation/widgets/payment_method_option.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Opens the Owner's checkout of a plan. Completes with the id of the
/// payment to show: the one just started, or the shop's pending payment
/// (`Billing.PaymentPending`); `null` when the sheet was closed.
Future<String?> showCheckoutSheet(
  BuildContext context, {
  required String planId,
  required String planName,
  required Money amount,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      CheckoutSheet(planId: planId, planName: planName, amount: amount),
);

/// The checkout (B3, plans-payments brief): the plan's amount read-only,
/// the method (card, wallet, kiosk) with a short explanation, the wallet
/// phone for a wallet. States: loading = the submit button spins while B3
/// runs; empty = not applicable (the plan is given); error = the failure
/// in a banner (the wallet phone's under its field), with "Open the
/// pending payment" for `Billing.PaymentPending`; data = the form, closed
/// with the started payment.
class CheckoutSheet extends ConsumerStatefulWidget {
  const new({
    required this.planId,
    required this.planName,
    required this.amount,
    super.key,
  });

  final String planId;
  final String planName;
  final Money amount;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final TextEditingController _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final provider = checkoutProvider(widget.planId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.payment), (_, payment) {
      if (payment != null) {
        Navigator.of(context).pop(payment.id);
      }
    });
    final failure = state.failure;
    final pendingId = state.pendingPaymentId;
    final phoneIssue = state.phoneIssue;
    final phoneError = phoneIssue != null
        ? walletPhoneIssueMessage(l10n, phoneIssue)
        : state.phoneMessages.isEmpty
        ? null
        : state.phoneMessages.join('\n');
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: EntranceScope(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsetsDirectional.all(spacing.md),
          children: [
            Text(
              l10n.billingCheckoutTitle(widget.planName),
              style: textTheme.titleLarge,
            ),
            SizedBox(height: spacing.sm),
            SurfaceCard(
              level: 0,
              color: colors.background,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.billingAmountLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ),
                  MoneyText(widget.amount),
                ],
              ),
            ),
            SizedBox(height: spacing.md),
            Text(l10n.billingMethodTitle, style: textTheme.titleMedium),
            for (final (index, method) in PaymentMethod.values.indexed)
              Padding(
                padding: EdgeInsetsDirectional.only(top: spacing.xs),
                child: Entrance(
                  index: index,
                  child: PaymentMethodOption(
                    method: method,
                    selected: state.method == method,
                    onSelected: state.isSubmitting
                        ? null
                        : () => notifier.selectMethod(method),
                  ),
                ),
              ),
            if (state.needsWalletPhone) ...[
              SizedBox(height: spacing.md),
              TextField(
                controller: _phone,
                enabled: !state.isSubmitting,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                onChanged: (_) => notifier.phoneChanged(),
                decoration: InputDecoration(
                  labelText: l10n.billingWalletPhone,
                  hintText: l10n.billingWalletPhoneHint,
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  errorText: phoneError,
                  errorMaxLines: 3,
                ),
              ),
            ],
            if (failure != null) ...[
              SizedBox(height: spacing.md),
              FormBanner(message: failureMessage(l10n, failure)),
            ],
            if (pendingId != null)
              Padding(
                padding: EdgeInsetsDirectional.only(top: spacing.xs),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(pendingId),
                  icon: const Icon(Icons.hourglass_top_rounded),
                  label: Text(l10n.billingOpenPendingPayment),
                ),
              ),
            SizedBox(height: spacing.lg),
            PrimaryButton(
              label: l10n.billingPay,
              busy: state.isSubmitting,
              onPressed: () => notifier.submit(walletPhone: _phone.text),
            ),
          ],
        ),
      ),
    );
  }
}
