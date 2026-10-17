import 'package:flutter/material.dart';

/// A [Hero] around a line of text that flies between two styles, for
/// example a product name from its list row to the detail header
/// (design-refresh brief). During the flight the style is interpolated and
/// the text scales down to fit the moving box.
class HeroText extends StatelessWidget {
  const new({
    required this.tag,
    required this.text,
    required this.style,
    this.maxLines,
    super.key,
  });

  final Object tag;
  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    flightShuttleBuilder: (context, animation, direction, from, to) {
      TextStyle? styleOf(BuildContext hero) => switch (hero.widget) {
        Hero(child: _HeroTextBody(:final style)) => style,
        _ => style,
      };
      final fromStyle = styleOf(from);
      final toStyle = styleOf(to);
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: _HeroTextBody(
            text: text,
            style: TextStyle.lerp(fromStyle, toStyle, animation.value),
            maxLines: 1,
          ),
        ),
      );
    },
    child: _HeroTextBody(text: text, style: style, maxLines: maxLines),
  );
}

/// The text inside a [HeroText], on a transparent material so it keeps
/// its style while flying.
class _HeroTextBody extends StatelessWidget {
  const new({required this.text, required this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    ),
  );
}
