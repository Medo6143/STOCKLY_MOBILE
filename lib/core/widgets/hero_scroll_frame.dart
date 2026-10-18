import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// Holds a screen that starts with a `HeroHeader` (dashboard, profile) on
/// an edge-to-edge display. The status bar strip is painted in the hero's
/// start colour with light status bar icons, and [child] is laid out below
/// it with the top inset removed, so the hero content (and anything
/// scrolled up) never draws under the clock or the battery.
class HeroScrollFrame extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SizedBox(
            height: top,
            child: ColoredBox(color: context.colors.heroStart),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
