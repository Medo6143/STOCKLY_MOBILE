import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Shown while the device has no network (design §3.2, §6.6). With
/// [margin] and rounded corners it can sit inside a hero header; online it
/// takes no space at all.
class OfflineBanner extends ConsumerWidget {
  const new({this.margin, this.rounded = false, super.key});

  /// Space around the banner, only while it is shown.
  final EdgeInsetsGeometry? margin;

  /// Rounded corners (`radii.md`) instead of a full-width strip.
  final bool rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectivityProvider).value ?? true) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final spacing = context.spacing;
    final banner = Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.warningSoft,
          borderRadius: rounded
              ? context.radii.circular(context.radii.md)
              : null,
        ),
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
    final margin = this.margin;
    return margin == null ? banner : Padding(padding: margin, child: banner);
  }
}
