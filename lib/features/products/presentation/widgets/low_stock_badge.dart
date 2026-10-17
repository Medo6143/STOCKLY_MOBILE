import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/status_pill.dart';

/// A small pill: "Low stock" in the soft warning colors, or any other
/// [label] in neutral colors (for example "Archived").
class LowStockBadge extends StatelessWidget {
  const new({required this.label, this.muted = false, super.key});

  final String label;

  /// Neutral colors instead of the warning colors.
  final bool muted;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: label,
    tone: muted ? PillTone.neutral : PillTone.warning,
  );
}
