import 'package:flutter/widgets.dart';

/// "Reduce motion" (rule 39): Android "Remove animations", iOS "Reduce
/// Motion". Animated widgets show their final frame when [reduced].
@immutable
final class StocklyMotion {
  const new({required this.reduced});

  factory of(BuildContext context) =>
      StocklyMotion(reduced: MediaQuery.disableAnimationsOf(context));

  final bool reduced;

  /// [duration], or zero when motion is reduced.
  Duration resolve(Duration duration) => reduced ? Duration.zero : duration;
}
