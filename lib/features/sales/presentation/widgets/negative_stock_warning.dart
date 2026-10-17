import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A `Stock.NegativeBalance` warning of a recorded sale (contract S1): the
/// sale went through and [productName]'s stock is now below zero.
class NegativeStockWarning extends StatelessWidget {
  const new({required this.productName, super.key});

  final String productName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningSoft,
          borderRadius: BorderRadiusDirectional.circular(context.radii.md),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.warning),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)
                      .salesNegativeStockWarning(productName),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
