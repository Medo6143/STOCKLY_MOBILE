import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
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
      child: Card(
        color: colors.warningSoft,
        margin: EdgeInsetsDirectional.zero,
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.cloud_upload_outlined, color: colors.warning),
          title: Text(
            AppLocalizations.of(context).scanQueuePendingCount(count),
          ),
          trailing: Icon(Icons.adaptive.arrow_forward, color: colors.muted),
        ),
      ),
    );
  }
}
