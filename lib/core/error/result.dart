import 'package:stockly/core/error/failure.dart';

/// Outcome of a repository or use-case call. Repositories never throw to the
/// UI: expected failures are an [Err] holding a [Failure].
sealed class Result<T, F extends Failure> {
  const new();
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const new(this.value);
  final T value;
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const new(this.failure);
  final F failure;
}

extension ResultToFuture<T, F extends Failure> on Result<T, F> {
  /// The value, or a failed future holding the [Failure], so an
  /// `AsyncNotifier.build` turns an [Err] into `AsyncError(failure)`.
  Future<T> toFuture() => switch (this) {
    Ok(:final value) => Future.value(value),
    Err(:final failure) => Future.error(failure, StackTrace.current),
  };
}
