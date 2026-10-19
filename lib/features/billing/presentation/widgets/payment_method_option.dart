import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/presentation/widgets/billing_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One payment method of the checkout: icon, name, a short explanation and
/// a check when [selected].
class PaymentMethodOption extends StatelessWidget {
  const new({
    required this.method,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final PaymentMethod method;
  final bool selected;

  /// `null` disables the option (while submitting).
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SurfaceCard(
        onTap: onSelected,
        level: selected ? 2 : 0,
        color: selected ? colors.mintSoft : null,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        child: Row(
          children: [
            LeadingBadge(
              icon: paymentMethodIcon(method),
              tone: selected ? PillTone.mint : PillTone.neutral,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paymentMethodLabel(l10n, method),
                    style: textTheme.titleMedium?.copyWith(color: colors.ink),
                  ),
                  Text(
                    paymentMethodHint(l10n, method),
                    style: textTheme.bodySmall?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(width: spacing.xs),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? colors.ink : colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
