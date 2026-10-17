import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// A placeholder block of a loading skeleton, shaped like the text or
/// picture it stands for. [widthFactor] is a share of the available width.
class SkeletonBox extends StatelessWidget {
  const new({
    required this.height,
    this.widthFactor = 1,
    this.radius,
    this.circle = false,
    this.alignment = AlignmentDirectional.centerStart,
    super.key,
  });

  final double height;
  final double widthFactor;

  /// Defaults to `radii.xs`.
  final double? radius;

  /// A circle of diameter [height] (avatars).
  final bool circle;

  /// Where the block sits in the available width.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.line,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : context.radii.circular(radius ?? context.radii.xs),
      ),
    );
    if (circle) {
      return SizedBox.square(dimension: height, child: box);
    }
    return FractionallySizedBox(
      alignment: alignment,
      widthFactor: widthFactor,
      child: SizedBox(height: height, child: box),
    );
  }
}
