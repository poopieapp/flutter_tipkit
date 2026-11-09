import 'package:flutter/widgets.dart';

/// What a [TipTransitionBuilder] knows about the tip it animates.
@immutable
class TipTransitionDetails {
  /// Creates the details.
  const TipTransitionDetails({
    required this.isPopover,
    this.arrowAlignment = Alignment.topCenter,
  });

  /// Whether the tip is a popover, rather than inline in the layout.
  final bool isPopover;

  /// Where the arrow's tip is within the tip's bounds: the natural origin
  /// for a scale. [Alignment.topCenter] for an inline tip without an arrow.
  final Alignment arrowAlignment;

  @override
  bool operator ==(Object other) =>
      other is TipTransitionDetails &&
      other.isPopover == isPopover &&
      other.arrowAlignment == arrowAlignment;

  @override
  int get hashCode => Object.hash(isPopover, arrowAlignment);
}

/// Animates a tip in and out.
///
/// [animation] runs from 0 (hidden) to 1 (shown) as the tip appears, and back
/// as it disappears, already curved by `TipThemeData.transitionCurve`. Like
/// `AnimatedSwitcher.transitionBuilder`.
typedef TipTransitionBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      TipTransitionDetails details,
      Widget child,
    );

/// The built-in [TipTransitionBuilder]s.
abstract final class TipTransitions {
  /// Grows the tip in from its top while it fades in, so the layout around
  /// an inline tip moves smoothly. The default for inline tips.
  static Widget reveal(
    BuildContext context,
    Animation<double> animation,
    TipTransitionDetails details,
    Widget child,
  ) {
    return TipRevealTransition(
      animation: animation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Scales the tip up from its arrow while it fades in. The default for
  /// popover tips.
  static Widget scale(
    BuildContext context,
    Animation<double> animation,
    TipTransitionDetails details,
    Widget child,
  ) {
    return ScaleTransition(
      scale: animation,
      alignment: details.arrowAlignment,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Only fades the tip in and out.
  static Widget fade(
    BuildContext context,
    Animation<double> animation,
    TipTransitionDetails details,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  /// Slides the tip a little away from its arrow while it fades in.
  static Widget slide(
    BuildContext context,
    Animation<double> animation,
    TipTransitionDetails details,
    Widget child,
  ) {
    final from = details.arrowAlignment;
    return SlideTransition(
      position: Tween(
        begin: Offset(-from.x * 0.08, -from.y * 0.08),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Grows [child] in from its top as `animation` goes from 0 to 1, taking
/// only as much height as is shown.
class TipRevealTransition extends AnimatedWidget {
  /// Creates the transition.
  const TipRevealTransition({
    required Animation<double> animation,
    required this.child,
    super.key,
  }) : super(listenable: animation);

  /// The widget to reveal.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: value.clamp(0, 1).toDouble(),
        child: child,
      ),
    );
  }
}
