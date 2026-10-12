import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';

/// The one way screens render loading, empty, error and data (rule 34,
/// design §9).
class AsyncStateView<T> extends ConsumerWidget {
  const new({
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.onRetry,
    this.errorBuilder,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;

  /// `null` means the data is never empty.
  final bool Function(T data)? isEmpty;

  /// Defaults to [EmptyState.generic].
  final Widget? empty;

  /// Defaults to [LoadingState].
  final Widget? loading;

  /// Shown as a retry button on the error state when not `null`.
  final VoidCallback? onRetry;

  /// Overrides the error state for special failures.
  final Widget Function(BuildContext context, Failure failure)? errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = this.value;
    if (value.hasValue) {
      final current = value.requireValue;
      final content = isEmpty?.call(current) ?? false
          ? empty ?? const EmptyState.generic()
          : data(context, current);
      if (!value.isLoading) {
        // A failed refresh keeps the data; the screen shows a snackbar.
        return content;
      }
      return Column(
        children: [
          const LinearProgressIndicator(),
          Expanded(child: content),
        ],
      );
    }
    if (value case AsyncError(:final error, :final stackTrace)) {
      final failure = _asFailure(ref, error, stackTrace);
      return errorBuilder?.call(context, failure) ??
          ErrorState(failure: failure, onRetry: onRetry);
    }
    return loading ?? const LoadingState();
  }

  /// Repositories never throw, so a non-[Failure] error is a bug: it is
  /// logged and shown as an unknown failure.
  Failure _asFailure(WidgetRef ref, Object error, StackTrace stackTrace) {
    if (error is Failure) {
      return error;
    }
    ref
        .read(appLoggerProvider)
        .error(
          'AsyncStateView got a non-Failure error',
          error: error,
          stackTrace: stackTrace,
        );
    return const UnknownApiFailure(info: ApiProblemInfo(status: 0));
  }
}
