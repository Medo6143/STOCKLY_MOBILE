import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// Page transitions of the app (design-refresh brief), all with durations
/// from `StocklyDurations.page` and curves from `StocklyCurves`. Under
/// reduce motion they take no time and never tick (rule 39).
abstract final class StocklyPages {
  /// A pushed screen: a shared-axis-like slide. The new page comes in from
  /// the end edge (the right in LTR, the left in RTL) while fading in; the
  /// page under it drifts a little towards the start edge.
  static Page<void> push(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => _page(context, state, child, slideTransition);

  /// A top-level screen (splash, sign-in, suspended): a fade-through, the
  /// new page fading in while it scales up slightly.
  static Page<void> fadeThrough(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => _page(context, state, child, fadeThroughTransition);

  static Page<void> _page(
    BuildContext context,
    GoRouterState state,
    Widget child,
    RouteTransitionsBuilder transitions,
  ) {
    final duration = StocklyMotion.of(context).resolve(context.durations.page);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      arguments: state.extra,
      restorationId: state.pageKey.value,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: transitions,
      child: child,
    );
  }

  /// The slide of [push], direction-aware: the horizontal offset where a
  /// pushed page starts, as a share of its width (positive is rightwards).
  static double slideStart(TextDirection direction) =>
      direction == TextDirection.ltr
      ? MotionGeometry.pushSlide
      : -MotionGeometry.pushSlide;

  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final start = slideStart(Directionality.of(context));
    final incoming = CurvedAnimation(
      parent: animation,
      curve: StocklyCurves.push,
      reverseCurve: StocklyCurves.push.flipped,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: StocklyCurves.push,
      reverseCurve: StocklyCurves.push.flipped,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset(start, 0),
        end: Offset.zero,
      ).animate(incoming),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: Offset(-start.sign * MotionGeometry.pushParallax, 0),
          ).animate(outgoing),
          child: child,
        ),
      ),
    );
  }

  static Widget fadeThroughTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: StocklyCurves.fadeThroughIn,
    );
    return FadeTransition(
      opacity: incoming,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: MotionGeometry.fadeThroughScale,
          end: 1,
        ).animate(incoming),
        child: child,
      ),
    );
  }
}
