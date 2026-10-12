import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Stands in for a screen that a later brief builds.
class PlaceholderScreen extends StatelessWidget {
  const new({this.title, super.key});

  /// Defaults to the app name.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title ?? l10n.appName)),
      body: EmptyState(
        title: l10n.commonComingSoonTitle,
        body: l10n.commonComingSoonBody,
      ),
    );
  }
}
