import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One queued scan (design §6.6): thumbnail, capture time, status text and
/// the actions of its state.
class PendingScanTile extends StatelessWidget {
  const new({
    required this.scan,
    required this.online,
    required this.now,
    required this.onDelete,
    required this.onRetake,
    super.key,
  });

  final PendingScan scan;
  final bool online;
  final DateTime now;
  final VoidCallback onDelete;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final failed = scan.status == PendingScanStatus.failedPermanent;
    final uploading = scan.status == PendingScanStatus.uploading;
    final thumbnail = spacing.huge;
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: context.radii.circular(context.radii.sm),
            child: SizedBox.square(
              dimension: thumbnail,
              child: Image.file(
                File(scan.imagePath),
                fit: BoxFit.cover,
                semanticLabel: l10n.scanCapturePreviewLabel,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.line,
                  child: Icon(Icons.receipt_long_outlined, color: colors.muted),
                ),
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.scanQueueCapturedAt(
                    ltrIsolate(
                      DateFormatter.dateTime(scan.capturedAt, language),
                    ),
                  ),
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  pendingScanStatusText(
                    l10n,
                    scan,
                    online: online,
                    now: now,
                    languageCode: language,
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: failed ? colors.danger : colors.muted,
                  ),
                ),
                if (!uploading)
                  Wrap(
                    spacing: spacing.xs,
                    children: [
                      if (failed)
                        TextButton.icon(
                          onPressed: onRetake,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l10n.scanCaptureRetake),
                        ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.danger,
                        ),
                        label: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
