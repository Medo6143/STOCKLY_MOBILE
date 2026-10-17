import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';

part 'scan_queue_state.freezed.dart';

/// The actions of the queue screen: a running "Retry now" and the last
/// action's failure.
@freezed
abstract class ScanQueueState with _$ScanQueueState {
  const factory({@Default(false) bool isRetrying, Failure? failure}) =
      _ScanQueueState;
}
