import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pulls [child] up by [overlap] over the widget before it in a column, so
/// content cards overlap the bottom edge of a hero header. The space it
/// takes is reduced by [overlap]; painting and hit testing follow the
/// child.
class OverlapUp extends SingleChildRenderObjectWidget {
  const new({required this.overlap, required Widget super.child, super.key});

  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderOverlapUp(overlap);

  @override
  void updateRenderObject(BuildContext context, RenderOverlapUp renderObject) {
    renderObject.overlap = overlap;
  }
}

/// The render object of [OverlapUp].
class RenderOverlapUp extends RenderShiftedBox {
  new(this._overlap) : super(null);

  double _overlap;

  /// How far the child is pulled up.
  double get overlap => _overlap;

  set overlap(double value) {
    if (value != _overlap) {
      _overlap = value;
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, -_overlap);
    final height = child.size.height - _overlap;
    size = constraints.constrain(
      Size(child.size.width, height < 0 ? 0 : height),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }
    final area = Rect.fromLTWH(0, -_overlap, size.width, child.size.height);
    if (!area.contains(position)) {
      return false;
    }
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  Rect get paintBounds =>
      Rect.fromLTWH(0, -_overlap, size.width, size.height + _overlap);
}
