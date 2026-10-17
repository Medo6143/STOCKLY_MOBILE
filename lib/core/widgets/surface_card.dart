import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// A rounded card on the raised surface (design-refresh brief): soft
/// shadows in light, a 1 px `line` border in dark. Tappable when [onTap] is
/// set, with the ripple clipped to the corners.
class SurfaceCard extends StatelessWidget {
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.level = 1,
    this.radius,
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Defaults to `spacing.md` on every side.
  final EdgeInsetsGeometry? padding;

  /// Elevation level 0, 1 or 2 (`StocklyElevation`).
  final int level;

  /// Defaults to `radii.lg`.
  final double? radius;

  /// Defaults to `colors.raisedSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final elevation = context.elevation;
    final border = elevation.border;
    final shape = BorderRadiusDirectional.circular(radius ?? context.radii.lg);
    final content = Padding(
      padding: padding ?? EdgeInsetsDirectional.all(context.spacing.md),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.colors.raisedSurface,
        borderRadius: shape,
        border: border == null ? null : Border.fromBorderSide(border),
        boxShadow: elevation.shadows(level),
      ),
      child: Material(
        type: MaterialType.transparency,
        animationDuration: Duration.zero,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}
