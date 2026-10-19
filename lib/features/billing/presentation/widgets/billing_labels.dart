import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Exhaustive enum-to-text mappings of the billing screens (design §8.3).

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.card => l10n.billingMethodCard,
      PaymentMethod.wallet => l10n.billingMethodWallet,
      PaymentMethod.kiosk => l10n.billingMethodKiosk,
    };

String paymentMethodHint(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.card => l10n.billingMethodCardHint,
      PaymentMethod.wallet => l10n.billingMethodWalletHint,
      PaymentMethod.kiosk => l10n.billingMethodKioskHint,
    };

IconData paymentMethodIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.wallet => Icons.account_balance_wallet_rounded,
  PaymentMethod.kiosk => Icons.storefront_rounded,
};

String paymentStatusLabel(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.pending => l10n.billingStatusPending,
      PaymentStatus.paid => l10n.billingStatusPaid,
      PaymentStatus.failed => l10n.billingStatusFailed,
      PaymentStatus.expired => l10n.billingStatusExpired,
    };

PillTone paymentStatusTone(PaymentStatus status) => switch (status) {
  PaymentStatus.pending => PillTone.warning,
  PaymentStatus.paid => PillTone.mint,
  PaymentStatus.failed => PillTone.danger,
  PaymentStatus.expired => PillTone.neutral,
};

String walletPhoneIssueMessage(AppLocalizations l10n, WalletPhoneIssue issue) =>
    switch (issue) {
      WalletPhoneIssue.required => l10n.billingWalletPhoneRequired,
      WalletPhoneIssue.invalid => l10n.billingWalletPhoneInvalid,
    };

/// "150.00 EGP / month", or "Free".
String planPriceLabel(AppLocalizations l10n, BillingPlan plan) => plan.isFree
    ? l10n.billingFree
    : l10n.billingPricePerMonth(
        l10n.moneyAmount(
          ltrIsolate(DecimalFormatter.formatMoney(plan.monthlyPrice)),
        ),
      );
