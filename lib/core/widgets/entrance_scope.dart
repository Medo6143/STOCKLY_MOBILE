import 'package:flutter/widgets.dart';

/// Lets `Entrance` animations below it play only on the first frame the
/// scope is shown (design-refresh brief: staggered entrance on first load,
/// not on every rebuild or page fetch). Items built later, for example the
/// next page of a list or a row scrolled back into view, appear at once.
class EntranceScope extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  /// Whether an entrance created now may still play: `true` outside any
  /// scope and during the scope's first frame.
  static bool isOpen(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_EntranceGateScope>()?.gate.open ??
      true;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final _EntranceGate _gate = _EntranceGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gate.open = false);
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceGateScope(gate: _gate, child: widget.child);
}

final class _EntranceGate {
  bool open = true;
}

class _EntranceGateScope extends InheritedWidget {
  const new({required this.gate, required super.child});

  final _EntranceGate gate;

  @override
  bool updateShouldNotify(_EntranceGateScope oldWidget) => false;
}
