import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Signs out from the profile or the settings screen. Queued scans stay on
/// the device and upload when this shop signs in again; with [pending]
/// scans the user confirms first (design §6.7).
Future<void> signOutWithWarning(
  BuildContext context,
  WidgetRef ref, {
  required int pending,
}) async {
  if (pending > 0) {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsSignOutPendingTitle),
        content: Text(l10n.settingsSignOutPendingBody(pending)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsSignOutAnyway),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) {
      return;
    }
  }
  await ref.read(signOutProvider.notifier).signOut();
}
