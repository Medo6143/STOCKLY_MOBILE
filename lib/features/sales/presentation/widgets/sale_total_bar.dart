import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The bottom bar of the quick sale: the total preview (the server's total
/// wins) and the submit button.
class SaleTotalBar extends StatelessWidget {
  const new({
    required this.total,
    required this.onSubmit,
    required this.submitting,
    super.key,
  });

  final Money total;

  /// `null` while the cart cannot be sent.
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return Material(
      elevation: spacing.xxs,
      color: context.colors.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.salesTotalLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    MoneyText(
                      total,
                      style: context.typo.numberLarge.copyWith(
                        color: context.colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  submitting ? l10n.salesSubmitting : l10n.salesSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
