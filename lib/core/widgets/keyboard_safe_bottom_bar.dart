import 'package:flutter/material.dart';

/// Wraps a `Scaffold.bottomNavigationBar` that holds the main action of a
/// screen with text fields (record the sale, confirm the invoice).
///
/// The scaffold shrinks its body above the keyboard but keeps the bottom
/// bar at the bottom of the screen, under the keyboard. This lifts the bar
/// by the keyboard's height so its button stays visible and tappable.
class KeyboardSafeBottomBar extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: child,
  );
}
