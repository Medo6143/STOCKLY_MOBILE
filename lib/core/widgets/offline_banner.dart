import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Shown while the device has no network (design §3.2, §6.6).
class OfflineBanner extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectivityProvider).value ?? true) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final spacing = context.spacing;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: colors.warningSoft,
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.md,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: colors.warning),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).commonOfflineBanner,
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
