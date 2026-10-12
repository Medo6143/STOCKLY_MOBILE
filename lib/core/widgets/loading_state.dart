import 'package:flutter/material.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Default loading state: a centered progress indicator.
class LoadingState extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(
      semanticsLabel: AppLocalizations.of(context).commonLoading,
    ),
  );
}
