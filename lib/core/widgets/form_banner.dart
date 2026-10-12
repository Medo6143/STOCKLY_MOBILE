import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// A failure message above a form (design §9: submit failures show as a
/// banner or under their field).
class FormBanner extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.dangerSoft,
          borderRadius: BorderRadiusDirectional.circular(context.radii.md),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: colors.danger),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  message,
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
