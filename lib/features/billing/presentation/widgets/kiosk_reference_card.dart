import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A pending kiosk payment: the reference number large (kept LTR, with a
/// copy button), the amount, the deadline and how to pay it in cash.
class KioskReferenceCard extends StatelessWidget {
  const new({required this.payment, super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final reference = payment.referenceNumber ?? '';
    final expiresAt = payment.expiresAt;
    final amount = l10n.moneyAmount(
      ltrIsolate(DecimalFormatter.formatMoney(payment.amount)),
    );
    return SurfaceCard(
      level: 2,
      radius: context.radii.xl,
      padding: EdgeInsetsDirectional.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.billingKioskTitle, style: textTheme.titleLarge),
          SizedBox(height: spacing.md),
          Text(
            l10n.billingKioskReference,
            style: textTheme.labelLarge?.copyWith(color: colors.muted),
          ),
          SizedBox(height: spacing.xxs),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  ltrIsolate(reference),
                  style: context.typo.numberLarge.copyWith(color: colors.ink),
                ),
              ),
              IconButton.filledTonal(
                tooltip: l10n.billingCopyReference,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: reference));
                  if (context.mounted) {
                    showMessageSnackBar(context, l10n.billingReferenceCopied);
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              l10n.billingPayBefore(
                ltrIsolate(DateFormatter.dateTime(expiresAt, language)),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colors.warning),
            ),
          ],
          SizedBox(height: spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.storefront_rounded, color: colors.muted),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  l10n.billingKioskSteps(amount),
                  style: textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
