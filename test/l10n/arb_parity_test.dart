import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final ar = _arb('ar');
  final en = _arb('en');

  test('ArbFiles_HaveTheSameKeys', () {
    expect(_messageKeys(en), _messageKeys(ar));
  });

  test('ArbFiles_HaveTheSamePlaceholders', () {
    for (final key in _messageKeys(ar)) {
      expect(
        _placeholders(en[key]! as String),
        _placeholders(ar[key]! as String),
        reason: key,
      );
    }
  });

  test('Template_DescribesEveryKey', () {
    for (final key in _messageKeys(ar)) {
      final meta = ar['@$key'];
      expect(meta, isA<Map<String, Object?>>(), reason: key);
      expect((meta! as Map)['description'], isNotEmpty, reason: key);
    }
  });

  test('EveryApiErrorCode_HasAnArbKeyNamedAfterTheCode', () {
    for (final code in ApiErrorCode.values) {
      final key = 'error${code.wire.replaceAll('.', '')}';
      expect(ar.containsKey(key), isTrue, reason: key);
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('EveryFailure_HasANonEmptyMessage_${locale.languageCode}', () {
      final l10n = lookupAppLocalizations(locale);
      final messages = <String>{};
      for (final code in ApiErrorCode.values) {
        final message = apiErrorMessage(l10n, code);
        expect(message.trim(), isNotEmpty, reason: code.wire);
        messages.add(message);
      }
      for (final failure in <Failure>[
        const NetworkFailure(),
        const TimeoutFailure(),
        const MalformedResponseFailure(),
        const UnknownApiFailure(info: ApiProblemInfo(status: 400)),
        const UnknownApiFailure(info: ApiProblemInfo(status: 503)),
        const SessionEndedFailure(
          ApiErrorCode.authRefreshTokenReused,
          ApiProblemInfo(status: 401),
        ),
        for (final reason in LocalFailureReason.values) LocalFailure(reason),
      ]) {
        expect(failureMessage(l10n, failure).trim(), isNotEmpty);
      }
      expect(
        failureMessage(
          l10n,
          const UnknownApiFailure(info: ApiProblemInfo(status: 503)),
        ),
        l10n.errorServer,
      );
      expect(
        failureMessage(
          l10n,
          const SessionEndedFailure(
            ApiErrorCode.authRefreshTokenReused,
            ApiProblemInfo(status: 401),
          ),
        ),
        l10n.errorSessionEnded,
      );
      expect(
        failureMessage(
          l10n,
          const ConflictFailure(
            ApiErrorCode.authEmailTaken,
            ApiProblemInfo(status: 409),
          ),
        ),
        l10n.errorAuthEmailTaken,
      );
    });
  }

  test('SupportedLocales_ArabicFirst', () {
    expect(AppLocalizations.supportedLocales, [
      const Locale('ar'),
      const Locale('en'),
    ]);
  });
}
