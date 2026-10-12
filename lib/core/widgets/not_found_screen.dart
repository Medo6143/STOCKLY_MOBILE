import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Shown for an unknown route, with a way home (design §3.3).
class NotFoundScreen extends StatelessWidget {
  const new({required this.onGoHome, super.key});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: EmptyState(
        title: l10n.notFoundTitle,
        body: l10n.notFoundBody,
        action: EmptyStateAction(label: l10n.commonGoHome, onPressed: onGoHome),
      ),
    );
  }
}
