import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/widgets/tip_theme.dart';

/// The edge of a tip that carries its arrow.
///
/// For a popover this also says where it opens: with the arrow on the [top]
/// edge, the tip sits below its target, pointing up at it.
enum TipArrowEdge {
  /// The arrow points up; a popover opens below its target.
  top,

  /// The arrow points down; a popover opens above its target.
  bottom,

  /// The arrow is on the leading edge (left in left-to-right text); a popover
  /// opens after its target.
  start,

  /// The arrow is on the trailing edge (right in left-to-right text); a
  /// popover opens before its target.
  end,
}

/// Where along its edge the arrow sits.
enum TipArrowAlignment {
  /// Near the leading corner: left on a top or bottom edge in
  /// left-to-right text, top on a side edge.
  start,

  /// In the middle of the edge.
  center,

  /// Near the trailing corner.
  end,
}

/// A physical side of a box.
enum TipSide {
  /// The top side.
  top,

  /// The bottom side.
  bottom,

  /// The left side.
  left,

  /// The right side.
  right;

  /// Whether the side runs horizontally.
  bool get isHorizontal => this == top || this == bottom;
}

/// Resolves [edge] to a physical side for [direction].
TipSide resolveArrowSide(TipArrowEdge edge, TextDirection direction) {
  final isLtr = direction == TextDirection.ltr;
  return switch (edge) {
    TipArrowEdge.top => TipSide.top,
    TipArrowEdge.bottom => TipSide.bottom,
    TipArrowEdge.start => isLtr ? TipSide.left : TipSide.right,
    TipArrowEdge.end => isLtr ? TipSide.right : TipSide.left,
  };
}

/// Whether [alignment] puts the arrow near the physical start (left or top)
/// of [side], near its end (right or bottom), or in the middle (null).
bool? resolveArrowNearPhysicalStart(
  TipArrowAlignment alignment,
  TipSide side,
  TextDirection direction,
) {
  final flips = side.isHorizontal && direction == TextDirection.rtl;
  return switch (alignment) {
    TipArrowAlignment.center => null,
    TipArrowAlignment.start => !flips,
    TipArrowAlignment.end => flips,
  };
}

/// The shape of a tip's arrow.
///
/// Implement it for arrows the built-in shapes cannot draw.
@immutable
abstract class TipArrowShape {
  /// Lets subclasses be `const`.
  const TipArrowShape();

  /// A straight triangle, `size.width` wide at its base and `size.height`
  /// high.
  const factory TipArrowShape.triangle({Size size}) = _TriangleArrowShape;

  /// A triangle whose tip is rounded off by `tipRadius`.
  const factory TipArrowShape.rounded({Size size, double tipRadius}) =
      _RoundedArrowShape;

  /// The width of the arrow's base and its height.
  Size get size;

  /// The outline of the arrow pointing up: its base on the x axis, centred
  /// on the origin, and its tip at `(0, -size.height)`.
  Path pathPointingUp();

  /// This shape scaled by [t], for `ShapeBorder.scale`.
  TipArrowShape scale(double t);
}

final class _TriangleArrowShape extends TipArrowShape {
  const _TriangleArrowShape({this.size = const Size(20, 10)});

  @override
  final Size size;

  @override
  Path pathPointingUp() {
    final half = size.width / 2;
    return Path()
      ..moveTo(-half, 0)
      ..lineTo(0, -size.height)
      ..lineTo(half, 0)
      ..close();
  }

  @override
  TipArrowShape scale(double t) => _TriangleArrowShape(size: size * t);

  @override
  bool operator ==(Object other) =>
      other is _TriangleArrowShape && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

final class _RoundedArrowShape extends TipArrowShape {
  const _RoundedArrowShape({
    this.size = const Size(20, 10),
    this.tipRadius = 3,
  });

  @override
  final Size size;

  final double tipRadius;

  @override
  Path pathPointingUp() {
    final half = size.width / 2;
    final tip = Offset(0, -size.height);
    final left = Offset(-half, 0);
    final right = Offset(half, 0);
    final edgeLength = (left - tip).distance;
    final cut = math.min(tipRadius, edgeLength / 2) / edgeLength;
    final beforeTip = tip + (left - tip) * cut;
    final afterTip = tip + (right - tip) * cut;
    return Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(beforeTip.dx, beforeTip.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, afterTip.dx, afterTip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
  }

  @override
  TipArrowShape scale(double t) =>
      _RoundedArrowShape(size: size * t, tipRadius: tipRadius * t);

  @override
  bool operator ==(Object other) =>
      other is _RoundedArrowShape &&
      other.size == size &&
      other.tipRadius == tipRadius;

  @override
  int get hashCode => Object.hash(size, tipRadius);
}

/// The outline of a tip: a rounded rectangle with an optional arrow on one
/// side, as a [ShapeBorder].
///
/// Use it in a `ShapeDecoration` like any other border, which gives tips
/// gradients and full `BoxShadow`s. The arrow lies inside the rectangle the
/// border is painted in: [dimensions] reserves room for it on [arrowSide].
@immutable
class TipBubbleBorder extends ShapeBorder {
  /// Creates the border.
  const TipBubbleBorder({
    this.side = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
    this.arrowSide,
    this.arrowShape = const TipArrowShape.triangle(),
    this.arrowNearPhysicalStart,
    this.arrowInset = 24,
    this.arrowPosition,
  });

  /// The outline drawn around the shape.
  final BorderSide side;

  /// The rounding of the body's corners.
  final BorderRadiusGeometry borderRadius;

  /// The side with the arrow, or null for none.
  final TipSide? arrowSide;

  /// What the arrow looks like.
  final TipArrowShape arrowShape;

  /// See [resolveArrowNearPhysicalStart]. Used when [arrowPosition] is null.
  final bool? arrowNearPhysicalStart;

  /// The arrow's distance from the corner when not centred.
  final double arrowInset;

  /// The arrow's centre, measured along its side from the left (top or
  /// bottom side) or the top (left or right side). Overrides
  /// [arrowNearPhysicalStart].
  final double? arrowPosition;

  /// The least distance from a corner to the arrow's centre on [arrowSide],
  /// so the arrow never overlaps a rounded corner.
  double arrowClearance(TextDirection? textDirection) {
    final side = arrowSide;
    if (side == null) return 0;
    final radius = borderRadius.resolve(textDirection);
    final corner = switch (side) {
      TipSide.top => math.max(radius.topLeft.x, radius.topRight.x),
      TipSide.bottom => math.max(radius.bottomLeft.x, radius.bottomRight.x),
      TipSide.left => math.max(radius.topLeft.y, radius.bottomLeft.y),
      TipSide.right => math.max(radius.topRight.y, radius.bottomRight.y),
    };
    return corner + arrowShape.size.width / 2;
  }

  /// A copy with the given fields replaced.
  TipBubbleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
    TipSide? arrowSide,
    TipArrowShape? arrowShape,
    bool? arrowNearPhysicalStart,
    double? arrowInset,
    double? arrowPosition,
  }) {
    return TipBubbleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
      arrowSide: arrowSide ?? this.arrowSide,
      arrowShape: arrowShape ?? this.arrowShape,
      arrowNearPhysicalStart:
          arrowNearPhysicalStart ?? this.arrowNearPhysicalStart,
      arrowInset: arrowInset ?? this.arrowInset,
      arrowPosition: arrowPosition ?? this.arrowPosition,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions {
    final height = arrowShape.size.height;
    return switch (arrowSide) {
      null => EdgeInsets.zero,
      TipSide.top => EdgeInsets.only(top: height),
      TipSide.bottom => EdgeInsets.only(bottom: height),
      TipSide.left => EdgeInsets.only(left: height),
      TipSide.right => EdgeInsets.only(right: height),
    };
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _outline(rect, textDirection);
  }

  /// The shape's outline in [rect], moved inwards by [inset].
  Path _outline(Rect rect, TextDirection? textDirection, {double inset = 0}) {
    final body = dimensions.resolve(textDirection).deflateRect(rect);
    final shape = Path()
      ..addRRect(
        borderRadius.resolve(textDirection).toRRect(body).deflate(inset),
      );
    final arrowSide = this.arrowSide;
    if (arrowSide == null) return shape;

    final length = arrowSide.isHorizontal ? body.width : body.height;
    final clearance = arrowClearance(textDirection);
    final requested =
        arrowPosition ??
        switch (arrowNearPhysicalStart) {
          null => length / 2,
          true => arrowInset,
          false => length - arrowInset,
        };
    final centre = requested.clamp(
      clearance,
      math.max(clearance, length - clearance),
    );
    final (origin, angle) = switch (arrowSide) {
      TipSide.top => (Offset(body.left + centre, body.top + inset), 0.0),
      TipSide.bottom => (
        Offset(body.left + centre, body.bottom - inset),
        math.pi,
      ),
      TipSide.left => (
        Offset(body.left + inset, body.top + centre),
        -math.pi / 2,
      ),
      TipSide.right => (
        Offset(body.right - inset, body.top + centre),
        math.pi / 2,
      ),
    };
    final transform = Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(Matrix4.rotationZ(angle));
    final arrow = arrowShape.pathPointingUp().transform(transform.storage);
    return Path.combine(PathOperation.union, shape, arrow);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _outline(rect, textDirection, inset: side.strokeInset);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    // The stroke is centred on its path, so the path goes where `strokeAlign`
    // puts the middle of the line. An inside border stays within the tip's
    // bounds, where a clip around the tip cannot cut it.
    canvas.drawPath(
      _outline(rect, textDirection, inset: -side.strokeOffset / 2),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) {
    final position = arrowPosition;
    return TipBubbleBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
      arrowSide: arrowSide,
      arrowShape: arrowShape.scale(t),
      arrowNearPhysicalStart: arrowNearPhysicalStart,
      arrowInset: arrowInset * t,
      arrowPosition: position == null ? null : position * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is TipBubbleBorder) return _lerpBubbleBorders(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is TipBubbleBorder) return _lerpBubbleBorders(this, b, t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is TipBubbleBorder &&
      other.side == side &&
      other.borderRadius == borderRadius &&
      other.arrowSide == arrowSide &&
      other.arrowShape == arrowShape &&
      other.arrowNearPhysicalStart == arrowNearPhysicalStart &&
      other.arrowInset == arrowInset &&
      other.arrowPosition == arrowPosition;

  @override
  int get hashCode => Object.hash(
    side,
    borderRadius,
    arrowSide,
    arrowShape,
    arrowNearPhysicalStart,
    arrowInset,
    arrowPosition,
  );
}

TipBubbleBorder _lerpBubbleBorders(
  TipBubbleBorder a,
  TipBubbleBorder b,
  double t,
) {
  final other = t < 0.5 ? a : b;
  final positionA = a.arrowPosition;
  final positionB = b.arrowPosition;
  return TipBubbleBorder(
    side: BorderSide.lerp(a.side, b.side, t),
    borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, b.borderRadius, t)!,
    arrowSide: other.arrowSide,
    arrowShape: other.arrowShape,
    arrowNearPhysicalStart: other.arrowNearPhysicalStart,
    arrowInset: lerpDouble(a.arrowInset, b.arrowInset, t)!,
    arrowPosition: positionA == null || positionB == null
        ? other.arrowPosition
        : lerpDouble(positionA, positionB, t),
  );
}

/// The shape of a tip: a [TipBubbleBorder], filled and outlined as the
/// [TipTheme] says, around [child].
///
/// The arrow lies inside the bubble's bounds: the bubble pads [child] by the
/// arrow's height on the arrow's edge.
class TipBubble extends StatelessWidget {
  /// Creates a bubble around [child].
  const TipBubble({
    required this.child,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.arrowPosition,
    this.shadows = const [],
    super.key,
  });

  /// The content of the bubble.
  final Widget child;

  /// The edge that carries the arrow. Null draws no arrow.
  final TipArrowEdge? arrowEdge;

  /// Where along [arrowEdge] the arrow sits.
  final TipArrowAlignment arrowAlignment;

  /// When it has a value, the arrow's centre, measured along the edge from
  /// the bubble's left (on the top or bottom edge) or top (on a side edge).
  /// Overrides [arrowAlignment]. Popovers use it to keep the arrow on their
  /// target when the bubble is shifted to stay on screen.
  final ValueListenable<double?>? arrowPosition;

  /// Shadows drawn under the bubble's shape.
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    final direction = Directionality.of(context);
    final edge = arrowEdge;
    final side = edge == null ? null : resolveArrowSide(edge, direction);
    final border = theme.bubbleBorder(
      arrowSide: side,
      arrowNearPhysicalStart: side == null
          ? null
          : resolveArrowNearPhysicalStart(arrowAlignment, side, direction),
    );
    return CustomPaint(
      painter: _TipBubblePainter(
        decoration: ShapeDecoration(
          color: theme.gradient == null ? theme.backgroundColor : null,
          gradient: theme.gradient,
          shadows: shadows,
          shape: border,
        ),
        textDirection: direction,
        arrowPosition: arrowPosition,
      ),
      child: Padding(padding: border.dimensions, child: child),
    );
  }
}

/// Paints a `ShapeDecoration` with a [TipBubbleBorder], moving the arrow to
/// the latest arrow position at paint time, after layout has set it.
class _TipBubblePainter extends CustomPainter {
  _TipBubblePainter({
    required this.decoration,
    required this.textDirection,
    this.arrowPosition,
  }) : super(repaint: arrowPosition);

  final ShapeDecoration decoration;
  final TextDirection textDirection;
  final ValueListenable<double?>? arrowPosition;

  ShapeDecoration get _current {
    final position = arrowPosition?.value;
    final border = decoration.shape;
    if (position == null || border is! TipBubbleBorder) return decoration;
    return ShapeDecoration(
      color: decoration.color,
      gradient: decoration.gradient,
      shadows: decoration.shadows,
      shape: border.copyWith(arrowPosition: position),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _current.createBoxPainter(_noImageChanges)
      ..paint(
        canvas,
        Offset.zero,
        ImageConfiguration(size: size, textDirection: textDirection),
      )
      ..dispose();
  }

  @override
  bool shouldRepaint(_TipBubblePainter oldDelegate) {
    return oldDelegate.decoration != decoration ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.arrowPosition != arrowPosition;
  }
}

/// Tip decorations have no images, so there is nothing to repaint for.
void _noImageChanges() {}
