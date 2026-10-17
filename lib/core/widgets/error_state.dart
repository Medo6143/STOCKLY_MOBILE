import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/core/widgets/state_illustration.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Shown when loading failed (design §9): the failure's message, a retry
/// button, a back button for "not found", and the error reference for
/// server and unknown errors.
class ErrorState extends StatelessWidget {
  const new({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reference = _reference;
    final onRetry = this.onRetry;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Entrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateIllustration(
                icon: failure is NetworkFailure
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                color: failure is NetworkFailure ? colors.muted : colors.danger,
                background: failure is NetworkFailure
                    ? colors.line
                    : colors.dangerSoft,
              ),
              SizedBox(height: spacing.lg),
              Text(
                l10n.commonErrorTitle,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.xs),
              Text(
                failureMessage(l10n, failure),
                style: textTheme.bodyMedium?.copyWith(color: colors.muted),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: spacing.xl),
                PressScale(
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.commonRetry),
                  ),
                ),
              ],
              if (failure is NotFoundFailure) ...[
                SizedBox(height: spacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.commonBack),
                ),
              ],
              if (reference != null) ...[
                SizedBox(height: spacing.lg),
                Text(
                  l10n.commonErrorReference(reference),
                  style: context.typo.code.copyWith(color: colors.muted),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                ),
                TextButton.icon(
                  onPressed: () => _copy(context, reference),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l10n.commonCopyErrorReference),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Only server and unknown errors offer a reference for support.
  String? get _reference => switch (failure) {
    ServerFailure(:final info) ||
    UnknownApiFailure(:final info) => info.reference,
    _ => null,
  };

  Future<void> _copy(BuildContext context, String reference) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = AppLocalizations.of(context).commonErrorReferenceCopied;
    final duration = context.durations.snackbar;
    await Clipboard.setData(ClipboardData(text: reference));
    messenger?.showSnackBar(
      SnackBar(content: Text(copied), duration: duration),
    );
  }
}
