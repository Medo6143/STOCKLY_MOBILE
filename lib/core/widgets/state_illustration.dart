import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// The large icon of an empty or error state, in a soft circle with a
/// fainter ring around it (design-refresh brief).
class StateIllustration extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    required this.background,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final inner = spacing.huge * 2;
    return Container(
      padding: EdgeInsetsDirectional.all(spacing.sm),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background.withValues(alpha: _ringAlpha),
      ),
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        child: Icon(icon, size: spacing.huge, color: color),
      ),
    );
  }

  static const double _ringAlpha = 0.45;
}
