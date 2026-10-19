import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/presentation/widgets/billing_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One payment of the history: method, plan, when, amount and status.
class PaymentTile extends StatelessWidget {
  const new({required this.payment, required this.onTap, super.key});

  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          LeadingBadge(
            icon: paymentMethodIcon(payment.method),
            tone: paymentStatusTone(payment.status),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.planName, style: textTheme.titleMedium),
                Text(
                  l10n.billingPaymentSubtitle(
                    paymentMethodLabel(l10n, payment.method),
                    ltrIsolate(
                      DateFormatter.dateTime(payment.createdAt, language),
                    ),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(payment.amount),
              SizedBox(height: spacing.xxs),
              StatusPill(
                label: paymentStatusLabel(l10n, payment.status),
                tone: paymentStatusTone(payment.status),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
