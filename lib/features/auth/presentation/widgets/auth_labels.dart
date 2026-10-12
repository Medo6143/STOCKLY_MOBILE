import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Exhaustive enum-to-text mappings of the auth screens (design §8.3).

String authFieldIssueLabel(AppLocalizations l10n, AuthFieldIssue issue) =>
    switch (issue) {
      AuthFieldIssue.required => l10n.authFieldRequired,
      AuthFieldIssue.invalidEmail => l10n.authFieldInvalidEmail,
      AuthFieldIssue.weakPassword => l10n.authFieldWeakPassword,
      AuthFieldIssue.tooLong => l10n.authFieldTooLong,
    };

String shopTypeLabel(AppLocalizations l10n, ShopType type) => switch (type) {
  ShopType.pharmacy => l10n.shopTypePharmacy,
  ShopType.grocery => l10n.shopTypeGrocery,
  ShopType.mobileShop => l10n.shopTypeMobileShop,
  ShopType.other => l10n.shopTypeOther,
};

/// The message under [field]: a device check first, then the server's
/// field message, then a failure that belongs to the field.
String? authFieldError(
  AppLocalizations l10n,
  AuthField field, {
  required Map<AuthField, AuthFieldIssue> issues,
  required Map<AuthField, List<String>> serverErrors,
  required Map<AuthField, Failure> fieldFailures,
}) {
  final issue = issues[field];
  if (issue != null) {
    return authFieldIssueLabel(l10n, issue);
  }
  final server = serverErrors[field];
  if (server != null && server.isNotEmpty) {
    return server.join('\n');
  }
  final failure = fieldFailures[field];
  return failure == null ? null : failureMessage(l10n, failure);
}

/// The banner text of a login or register failure. Lockout and rate limit
/// show the time left (contract v1.4).
String authBannerMessage(
  AppLocalizations l10n,
  Failure failure, {
  Duration? lockoutRemaining,
  Duration? retryAfterRemaining,
}) => switch (failure) {
  AccountLockedFailure(:final retryAfter) => l10n.authLockedOut(
    _wholeUnits(lockoutRemaining ?? retryAfter, const Duration(minutes: 1)),
  ),
  AuthRateLimitedFailure(:final retryAfter) => l10n.authTooManyRequests(
    _wholeUnits(retryAfterRemaining ?? retryAfter, const Duration(seconds: 1)),
  ),
  _ => failureMessage(l10n, failure),
};

/// [value] in whole [unit]s, rounded up and at least 1.
int _wholeUnits(Duration value, Duration unit) {
  final units =
      (value.inMicroseconds + unit.inMicroseconds - 1) ~/ unit.inMicroseconds;
  return units < 1 ? 1 : units;
}
