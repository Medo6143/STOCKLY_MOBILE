import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// "N scans waiting to upload" at the top of the invoice list, linking to
/// the queue (design §6.6).
class PendingScansCard extends StatelessWidget {
  const new({required this.count, required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.md,
        spacing.xs,
        spacing.md,
        0,
      ),
      child: SurfaceCard(
        onTap: onTap,
        color: colors.warningSoft,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: colors.warning),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                AppLocalizations.of(context).scanQueuePendingCount(count),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
