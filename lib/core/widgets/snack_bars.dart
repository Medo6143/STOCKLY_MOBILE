import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Shows [message] in a snackbar, if the screen has a messenger.
void showMessageSnackBar(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: context.durations.snackbar),
    );

/// Shows the message of [failure] in a snackbar.
void showFailureSnackBar(BuildContext context, Failure failure) =>
    showMessageSnackBar(
      context,
      failureMessage(AppLocalizations.of(context), failure),
    );

/// A refresh that failed while data is shown keeps the data and shows the
/// failure in a snackbar (design §9, rule 5). Call from `ref.listen`.
void showRefreshFailure(BuildContext context, AsyncValue<Object?> value) {
  if (value case AsyncError(:final error) when value.hasValue) {
    showFailureSnackBar(
      context,
      error is Failure
          ? error
          : const UnknownApiFailure(info: ApiProblemInfo(status: 0)),
    );
  }
}
