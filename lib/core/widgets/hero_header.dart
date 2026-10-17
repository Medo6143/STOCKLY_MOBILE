import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// The gradient header of the dashboard and the profile (design-refresh
/// brief): navy → ink in light, background → surface in dark, a mint glow
/// in the end corner and two soft rings. It reaches under the status bar
/// and leaves [overlap] free at the bottom for the cards that overlap its
/// edge (see `OverlapUp`). Text on it uses `onHero` / `onHeroMuted`.
class HeroHeader extends StatelessWidget {
  const new({required this.child, this.overlap = 0, super.key});

  final Widget child;

  /// Extra space at the bottom, covered by the overlapping cards.
  final double overlap;

  static const double _glowRadius = 1.2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final shape = BorderRadiusDirectional.vertical(
      bottom: Radius.circular(context.radii.xxl),
    );
    final bigRing = spacing.huge * 4;
    final smallRing = spacing.huge * 2;
    Widget ring(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.heroDecoration, width: spacing.xs),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: shape,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [colors.heroStart, colors.heroEnd],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: AlignmentDirectional.topEnd,
                      radius: _glowRadius,
                      colors: [
                        colors.heroGlow,
                        colors.heroGlow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: -bigRing / 2,
                end: -bigRing / 4,
                child: ring(bigRing),
              ),
              PositionedDirectional(
                bottom: -smallRing / 3,
                start: -smallRing / 3,
                child: ring(smallRing),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg + overlap,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: colors.onHero),
                    child: IconTheme.merge(
                      data: IconThemeData(color: colors.onHero),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
