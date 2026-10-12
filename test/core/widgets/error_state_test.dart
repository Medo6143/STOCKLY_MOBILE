import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/widgets/error_state.dart';

import '../../helpers/pump_app.dart';

const ApiProblemInfo _info = ApiProblemInfo(
  status: 500,
  traceId: '00-4bf92f3577b34da6-00',
  correlationId: 'cid-1',
);

void main() {
  testWidgets('NotFound_ShowsBackButtonAndNoReference', (tester) async {
    final locale = localeVariant.currentValue!;
    final l10n = l10nOf(locale);
    await pumpLocalizedApp(
      tester,
      const ErrorState(
        failure: NotFoundFailure(
          ApiErrorCode.productNotFound,
          ApiProblemInfo(status: 404, traceId: 'hidden'),
        ),
      ),
      locale: locale,
    );

    expect(find.text(l10n.errorProductNotFound), findsOneWidget);
    expect(find.text(l10n.commonBack), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
    expect(find.text(l10n.commonCopyErrorReference), findsNothing);
    await tester.tap(find.text(l10n.commonBack));
    await tester.pump();
  }, variant: localeVariant);

  testWidgets('ServerFailure_ShowsAndCopiesReference', (tester) async {
    final locale = localeVariant.currentValue!;
    final l10n = l10nOf(locale);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpLocalizedApp(
      tester,
      const ErrorState(
        failure: ServerFailure(ApiErrorCode.serverUnexpected, _info),
      ),
      locale: locale,
    );

    expect(find.text(l10n.errorServerUnexpected), findsOneWidget);
    expect(
      find.text(l10n.commonErrorReference(_info.traceId!)),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonCopyErrorReference));
    await tester.pump();

    expect(copied, [_info.traceId]);
    expect(find.text(l10n.commonErrorReferenceCopied), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('UnknownApiFailure_ReferenceFallsBackToCorrelationId', (
    tester,
  ) async {
    final locale = localeVariant.currentValue!;
    final l10n = l10nOf(locale);
    await pumpLocalizedApp(
      tester,
      const ErrorState(
        failure: UnknownApiFailure(
          info: ApiProblemInfo(status: 502, correlationId: 'cid-9'),
        ),
      ),
      locale: locale,
    );

    expect(find.text(l10n.errorServer), findsOneWidget);
    expect(find.text(l10n.commonErrorReference('cid-9')), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('NetworkFailure_UsesOfflineIconInMutedColor', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      const ErrorState(failure: NetworkFailure()),
      locale: locale,
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
    expect(icon.color, StocklyColors.light.muted);
    expect(find.text(l10nOf(locale).errorNetwork), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('OtherFailure_UsesDangerColor_DarkTheme', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      const ErrorState(failure: TimeoutFailure()),
      locale: locale,
      themeMode: ThemeMode.dark,
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(icon.color, StocklyColors.dark.danger);
    expect(find.text(l10nOf(locale).errorTimeout), findsOneWidget);
  }, variant: localeVariant);
}
