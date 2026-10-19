import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/fake_backend/panel/fake_backend_panel_notifier.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Debug actions of a pending payment in fake mode (plans-payments brief):
/// the fake provider reports it paid or failed, as its callback would, so
/// QA can finish the flow without the hosted page. [onSettled] lets the
/// screen ask the server again.
class FakePaymentPanel extends ConsumerWidget {
  const new({required this.paymentId, required this.onSettled, super.key});

  final String paymentId;
  final VoidCallback onSettled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    void settle({required bool paid}) {
      ref
          .read(fakeBackendPanelProvider.notifier)
          .settlePayment(paymentId, paid: paid);
      Navigator.of(context).pop();
      onSettled();
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
        children: [
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
            child: Text(
              l10n.fakePanelPaymentTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: Text(l10n.fakePanelPaymentSuccess),
            onTap: () => settle(paid: true),
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: Text(l10n.fakePanelPaymentFailure),
            onTap: () => settle(paid: false),
          ),
        ],
      ),
    );
  }
}
