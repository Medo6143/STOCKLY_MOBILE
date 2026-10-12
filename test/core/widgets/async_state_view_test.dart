import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';

import '../../helpers/pump_app.dart';

const Key _dataKey = Key('data');

Widget _view(
  AsyncValue<List<int>> value, {
  VoidCallback? onRetry,
  Widget? empty,
}) => AsyncStateView<List<int>>(
  value: value,
  isEmpty: (items) => items.isEmpty,
  empty: empty,
  onRetry: onRetry,
  data: (context, items) => Text(items.join(','), key: _dataKey),
);

final class _RecordingLogger implements AppLogger {
  final List<String> errors = [];

  @override
  void info(String message) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      errors.add(message);
}

void main() {
  testWidgets('Loading_ShowsLoadingState', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(tester, _view(const AsyncLoading()), locale: locale);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.bySemanticsLabel(l10nOf(locale).commonLoading), findsOneWidget);
    expect(find.byKey(_dataKey), findsNothing);
  }, variant: localeVariant);

  testWidgets('Empty_ShowsGenericEmptyState', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(tester, _view(const AsyncData([])), locale: locale);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(l10nOf(locale).commonEmptyTitle), findsOneWidget);
    expect(find.text(l10nOf(locale).commonEmptyBody), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_CustomEmptyWithAction', (tester) async {
    final locale = localeVariant.currentValue!;
    var tapped = false;
    await pumpLocalizedApp(
      tester,
      _view(
        const AsyncData([]),
        empty: EmptyState(
          title: l10nOf(locale).navProducts,
          action: EmptyStateAction(
            label: l10nOf(locale).commonGoHome,
            onPressed: () => tapped = true,
          ),
        ),
      ),
      locale: locale,
    );

    expect(find.text(l10nOf(locale).navProducts), findsOneWidget);
    await tester.tap(find.text(l10nOf(locale).commonGoHome));
    expect(tapped, isTrue);
  }, variant: localeVariant);

  testWidgets('Error_ShowsMessageAndRetry', (tester) async {
    final locale = localeVariant.currentValue!;
    var retries = 0;
    await pumpLocalizedApp(
      tester,
      _view(
        const AsyncError(NetworkFailure(), StackTrace.empty),
        onRetry: () => retries++,
      ),
      locale: locale,
    );

    final l10n = l10nOf(locale);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n.commonErrorTitle), findsOneWidget);
    expect(find.text(l10n.errorNetwork), findsOneWidget);
    await tester.tap(find.text(l10n.commonRetry));
    expect(retries, 1);
  }, variant: localeVariant);

  testWidgets('Data_ShowsTheData', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      _view(const AsyncData([1, 2, 3])),
      locale: locale,
    );

    expect(find.text('1,2,3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  }, variant: localeVariant);

  testWidgets('NonFailureError_ShownAsUnknownAndLogged', (tester) async {
    final locale = localeVariant.currentValue!;
    final logger = _RecordingLogger();
    await pumpLocalizedApp(
      tester,
      _view(AsyncError(StateError('bug'), StackTrace.empty)),
      locale: locale,
      overrides: [appLoggerProvider.overrideWithValue(logger)],
    );

    expect(find.text(l10nOf(locale).errorUnknown), findsOneWidget);
    expect(logger.errors, hasLength(1));
  }, variant: localeVariant);

  testWidgets('ErrorBuilder_OverridesErrorState', (tester) async {
    await pumpLocalizedApp(
      tester,
      AsyncStateView<int>(
        value: const AsyncError(TimeoutFailure(), StackTrace.empty),
        data: (context, value) => Text('$value'),
        errorBuilder: (context, failure) =>
            Text(failure.runtimeType.toString()),
      ),
      locale: const Locale('en'),
    );

    expect(find.text('TimeoutFailure'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('NeverEmptyWhenIsEmptyIsNull', (tester) async {
    await pumpLocalizedApp(
      tester,
      AsyncStateView<List<int>>(
        value: const AsyncData([]),
        data: (context, items) => const Text('empty list is data'),
      ),
      locale: const Locale('ar'),
    );

    expect(find.text('empty list is data'), findsOneWidget);
  });

  testWidgets('Refresh_KeepsDataWithProgressThenKeepsDataOnError', (
    tester,
  ) async {
    final completers = <Completer<List<int>>>[];
    final listProvider = FutureProvider<List<int>>((ref) {
      final completer = Completer<List<int>>();
      completers.add(completer);
      return completer.future;
    });
    await pumpLocalizedApp(
      tester,
      Consumer(builder: (context, ref, _) => _view(ref.watch(listProvider))),
      locale: const Locale('ar'),
    );
    completers.single.complete([7]);
    await tester.pump();
    expect(find.text('7'), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(Consumer)))
        .invalidate(listProvider);
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    completers.last.completeError(const NetworkFailure());
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Rtl_DirectionFollowsLocale', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      _view(const AsyncError(NetworkFailure(), StackTrace.empty)),
      locale: locale,
    );

    expect(
      Directionality.of(tester.element(find.byType(ErrorState))),
      locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    );
  }, variant: localeVariant);

  testWidgets('DarkTheme_AllStatesRenderWithDarkTokens', (tester) async {
    final locale = localeVariant.currentValue!;
    for (final value in <AsyncValue<List<int>>>[
      const AsyncLoading(),
      const AsyncData([]),
      const AsyncError(
        ServerFailure(
          ApiErrorCode.serverUnexpected,
          ApiProblemInfo(status: 500, traceId: '00-t-00'),
        ),
        StackTrace.empty,
      ),
      const AsyncData([4]),
    ]) {
      await pumpLocalizedApp(
        tester,
        _view(value, onRetry: () {}),
        locale: locale,
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(AsyncStateView<List<int>>));
      expect(Theme.of(context).extension<StocklyColors>(), StocklyColors.dark);
    }
  }, variant: localeVariant);
}
