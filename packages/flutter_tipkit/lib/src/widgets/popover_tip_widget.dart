import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/model/tip_group.dart';
import 'package:flutter_tipkit/src/widgets/tip_bubble.dart';
import 'package:flutter_tipkit/src/widgets/tip_card.dart';
import 'package:flutter_tipkit/src/widgets/tip_display.dart';
import 'package:flutter_tipkit/src/widgets/tip_theme.dart';
import 'package:flutter_tipkit/src/widgets/tip_transitions.dart';

/// What a tap outside a popover tip does.
enum TipBarrierBehavior {
  /// Closes the tip: invalidates it with `TipInvalidationReason.tipClosed`.
  close,

  /// Hides the tip while this `PopoverTipWidget` stays mounted, without
  /// invalidating it.
  dismiss,

  /// Nothing: the tip stays until one of its buttons is tapped, and the rest
  /// of the screen does not react to taps.
  block,
}

/// A tip that opens over the screen, pointing at [child].
///
/// Only one popover tip shows at a time; others wait until it closes.
///
/// ```dart
/// PopoverTipWidget(
///   tip: const FavoriteTip(),
///   arrowEdge: TipArrowEdge.top,
///   child: IconButton(icon: const Icon(Icons.star), onPressed: save),
/// )
/// ```
class PopoverTipWidget extends StatefulWidget {
  /// Points [tip] at [child] when the tip may be displayed.
  ///
  /// With a [group] too, shows [tip] only while it is the group's current
  /// tip, so the tips of one group can point at different widgets.
  const PopoverTipWidget({
    required Tip this.tip,
    required this.child,
    this.group,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.content,
    this.leading,
    this.showCloseButton,
    this.barrierBehavior = TipBarrierBehavior.close,
    this.onAction,
    this.onClose,
    this.cardBuilder,
    this.transitionBuilder,
    super.key,
  });

  /// Points the current tip of [group] at [child].
  const PopoverTipWidget.group(
    TipGroup this.group, {
    required this.child,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.content,
    this.leading,
    this.showCloseButton,
    this.barrierBehavior = TipBarrierBehavior.close,
    this.onAction,
    this.onClose,
    this.cardBuilder,
    this.transitionBuilder,
    super.key,
  }) : tip = null;

  /// The tip to show.
  final Tip? tip;

  /// The group whose current tip to show.
  final TipGroup? group;

  /// The widget the tip points at.
  final Widget child;

  /// The edge of the tip with the arrow, which also says where the tip opens:
  /// with [TipArrowEdge.top] it opens below [child].
  ///
  /// Null opens the tip below or above [child], wherever there is more room.
  final TipArrowEdge? arrowEdge;

  /// Where along [arrowEdge] the arrow sits. The tip is shifted to stay on
  /// screen and the arrow follows, so it always points at [child].
  final TipArrowAlignment arrowAlignment;

  /// Provides the content instead of `Tip.content`.
  final TipContentResolver? content;

  /// Replaces [TipThemeData.leading].
  final Widget? leading;

  /// Replaces [TipThemeData.showCloseButton].
  final bool? showCloseButton;

  /// What a tap outside the tip does.
  final TipBarrierBehavior barrierBehavior;

  /// Called after an action is tapped, and the tip invalidated if the action
  /// says so.
  final TipActionCallback? onAction;

  /// Called after the tip is closed, with its close button or a tap outside.
  final TipCloseCallback? onClose;

  /// Draws the tip instead of [TipThemeData.cardBuilder] or the default
  /// [TipCard]. To keep the arrow pointing at [child] when the tip is
  /// shifted to stay on screen, draw it with a [TipBubble] given
  /// [TipCardDetails.arrowPosition].
  final TipCardBuilder? cardBuilder;

  /// Animates the tip instead of [TipThemeData.popoverTransitionBuilder].
  final TipTransitionBuilder? transitionBuilder;

  @override
  State<PopoverTipWidget> createState() => _PopoverTipWidgetState();
}

class _PopoverTipWidgetState extends State<PopoverTipWidget>
    with SingleTickerProviderStateMixin, TipDisplayStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final ValueNotifier<double?> _arrowPosition = ValueNotifier(null);
  late final AnimationController _animation = AnimationController(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeInOut,
  );

  /// The tip this popover reports as displayed.
  Tip? _shown;

  /// The tip to render, kept while it animates out.
  Tip? _rendered;

  /// A tip dismissed with [TipBarrierBehavior.dismiss].
  String? _dismissedTipId;

  /// Where the target was when the tip was last placed.
  Rect? _placedTargetRect;

  /// Whether the target's place is checked after the next frame.
  bool _isWatchingTarget = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = TipTheme.of(context);
    _animation.duration = theme.transitionDuration;
    _curved.curve = theme.transitionCurve;
  }

  @override
  void didUpdateWidget(PopoverTipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tip != widget.tip || oldWidget.group != widget.group) {
      scheduleTipSync();
    }
  }

  @override
  void syncTipDisplay() {
    var target = resolveTipForHost(tip: widget.tip, group: widget.group);
    if (target != null && target.id == _dismissedTipId) target = null;
    if (target != null && !Tips.center.claimPopover(this)) target = null;
    if (target == _shown) return;
    final previous = _shown;
    _shown = target;
    if (previous != null) Tips.center.endDisplay(previous);
    if (target != null) {
      Tips.center.beginDisplay(target);
      _rendered = target;
      _portal.show();
      _animation.forward();
    } else if (isHostVisible) {
      _animation.reverse();
    } else {
      // Tickers are off when the view is not visible, so an exit animation
      // would never end. Hiding at once also removes a popover's barrier.
      _animation.value = 0;
    }
    setState(() {});
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _shown != null) return;
    _portal.hide();
    Tips.center.releasePopover(this);
    if (mounted) setState(() => _rendered = null);
  }

  /// Places the tip again whenever the target has moved, for example while
  /// its route slides into place. Following the target alone would carry the
  /// tip off screen, because the tip is kept on screen only when placed.
  void _watchTarget() {
    if (_isWatchingTarget) return;
    _isWatchingTarget = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isWatchingTarget = false;
      if (!mounted || _rendered == null) return;
      _watchTarget();
      final targetBox = context.findRenderObject() as RenderBox?;
      final overlayBox =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (targetBox == null ||
          overlayBox == null ||
          !targetBox.attached ||
          !targetBox.hasSize ||
          !overlayBox.hasSize) {
        return;
      }
      if (_targetRectIn(targetBox, overlayBox) != _placedTargetRect) {
        setState(() {});
      }
    });
  }

  Rect _targetRectIn(RenderBox targetBox, RenderBox overlayBox) {
    return MatrixUtils.transformRect(
      targetBox.getTransformTo(overlayBox),
      Offset.zero & targetBox.size,
    );
  }

  void _onBarrierTap() {
    final tip = _shown;
    if (tip == null) return;
    switch (widget.barrierBehavior) {
      case TipBarrierBehavior.close:
        tip.invalidate(TipInvalidationReason.tipClosed);
        widget.onClose?.call(tip);
      case TipBarrierBehavior.dismiss:
        _dismissedTipId = tip.id;
        scheduleTipSync();
      case TipBarrierBehavior.block:
        break;
    }
  }

  @override
  void dispose() {
    final shown = _shown;
    if (shown != null) Tips.center.endDisplay(shown);
    Tips.center.releasePopover(this);
    _curved.dispose();
    _animation.dispose();
    _arrowPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: widget.child,
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final tip = _rendered;
    final targetBox = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (tip == null ||
        targetBox == null ||
        overlayBox == null ||
        !targetBox.hasSize ||
        !overlayBox.hasSize) {
      return const SizedBox.shrink();
    }
    final theme = TipTheme.of(context);
    final direction = Directionality.of(context);
    final overlaySize = overlayBox.size;
    final targetRect = _targetRectIn(targetBox, overlayBox);
    _placedTargetRect = targetRect;
    _watchTarget();
    final safeArea =
        MediaQuery.maybePaddingOf(overlayContext) ?? EdgeInsets.zero;
    final margin = theme.popoverMargin + safeArea;
    final edge =
        widget.arrowEdge ??
        (overlaySize.height - targetRect.bottom >= targetRect.top
            ? TipArrowEdge.top
            : TipArrowEdge.bottom);
    final side = resolveArrowSide(edge, direction);
    final nearStart = resolveArrowNearPhysicalStart(
      widget.arrowAlignment,
      side,
      direction,
    );

    final details = TipCardDetails(
      tip: tip,
      content: widget.content?.call(context, tip) ?? tip.content,
      isPopover: true,
      leading: widget.leading,
      showCloseButton: widget.showCloseButton,
      arrowEdge: edge,
      arrowAlignment: widget.arrowAlignment,
      arrowPosition: _arrowPosition,
      onAction: (action) {
        Tips.center.performAction(tip, action);
        widget.onAction?.call(tip, action);
      },
      onClose: () {
        tip.invalidate(TipInvalidationReason.tipClosed);
        widget.onClose?.call(tip);
      },
    );
    final card =
        (widget.cardBuilder ?? theme.cardBuilder)?.call(context, details) ??
        TipCard.fromDetails(details);
    final transition =
        widget.transitionBuilder ?? theme.popoverTransitionBuilder;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _shown == null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onBarrierTap,
              child: FadeTransition(
                opacity: _curved,
                child: ColoredBox(color: theme.barrierColor),
              ),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: -targetRect.topLeft,
          child: SizedBox.fromSize(
            size: overlaySize,
            child: CustomSingleChildLayout(
              delegate: PopoverTipLayoutDelegate(
                targetRect: targetRect,
                side: side,
                nearPhysicalStart: nearStart,
                margin: margin,
                gap: theme.popoverGap,
                maxWidth: math.min(
                  theme.popoverMaxWidth,
                  overlaySize.width * theme.popoverMaxWidthFactor,
                ),
                arrowInset: theme.arrowInset,
                arrowClearance: theme
                    .bubbleBorder(arrowSide: side)
                    .arrowClearance(direction),
                arrowPosition: _arrowPosition,
              ),
              child: IgnorePointer(
                ignoring: _shown == null,
                child: transition(
                  context,
                  _curved,
                  TipTransitionDetails(
                    isPopover: true,
                    arrowAlignment: _arrowAlignment(side, nearStart),
                  ),
                  card,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Alignment _arrowAlignment(TipSide side, bool? nearPhysicalStart) {
  final along = switch (nearPhysicalStart) {
    null => 0.0,
    true => -1.0,
    false => 1.0,
  };
  return switch (side) {
    TipSide.top => Alignment(along, -1),
    TipSide.bottom => Alignment(along, 1),
    TipSide.left => Alignment(-1, along),
    TipSide.right => Alignment(1, along),
  };
}

/// Places a popover tip next to its target, inside the screen, and moves its
/// arrow so it points at the target.
@visibleForTesting
class PopoverTipLayoutDelegate extends SingleChildLayoutDelegate {
  /// Creates the delegate.
  PopoverTipLayoutDelegate({
    required this.targetRect,
    required this.side,
    required this.nearPhysicalStart,
    required this.margin,
    required this.gap,
    required this.maxWidth,
    required this.arrowInset,
    required this.arrowClearance,
    required this.arrowPosition,
  });

  /// The target, in the overlay's coordinates.
  final Rect targetRect;

  /// The side of the tip that carries the arrow.
  final TipSide side;

  /// See [resolveArrowNearPhysicalStart].
  final bool? nearPhysicalStart;

  /// The least space between the tip and the overlay's edges.
  final EdgeInsets margin;

  /// The space between the arrow and the target.
  final double gap;

  /// The widest the tip gets.
  final double maxWidth;

  /// The arrow's distance from the corner when not centred.
  final double arrowInset;

  /// The least distance from a corner to the arrow's centre.
  final double arrowClearance;

  /// Receives the arrow's centre along the tip's edge, after layout.
  final ValueNotifier<double?> arrowPosition;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final width = switch (side) {
      TipSide.top || TipSide.bottom => size.width - margin.horizontal,
      TipSide.left => size.width - margin.right - targetRect.right - gap,
      TipSide.right => targetRect.left - gap - margin.left,
    };
    final height = switch (side) {
      TipSide.top => size.height - margin.bottom - targetRect.bottom - gap,
      TipSide.bottom => targetRect.top - gap - margin.top,
      TipSide.left || TipSide.right => size.height - margin.vertical,
    };
    return BoxConstraints(
      maxWidth: math.max(0, math.min(maxWidth, width)),
      maxHeight: math.max(0, height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    switch (side) {
      case TipSide.top:
      case TipSide.bottom:
        final x = _along(
          anchor: targetRect.center.dx,
          length: childSize.width,
          start: margin.left,
          end: size.width - margin.right,
        );
        final y = side == TipSide.top
            ? targetRect.bottom + gap
            : targetRect.top - gap - childSize.height;
        return Offset(x, y);
      case TipSide.left:
      case TipSide.right:
        final y = _along(
          anchor: targetRect.center.dy,
          length: childSize.height,
          start: margin.top,
          end: size.height - margin.bottom,
        );
        final x = side == TipSide.left
            ? targetRect.right + gap
            : targetRect.left - gap - childSize.width;
        return Offset(x, y);
    }
  }

  /// Where the tip starts along the edge with the arrow, kept between
  /// [start] and [end]; also stores where its arrow goes.
  double _along({
    required double anchor,
    required double length,
    required double start,
    required double end,
  }) {
    final desired = switch (nearPhysicalStart) {
      null => anchor - length / 2,
      true => anchor - arrowInset,
      false => anchor - length + arrowInset,
    };
    final position = desired
        .clamp(start, math.max(start, end - length))
        .toDouble();
    final lastCentre = math.max(arrowClearance, length - arrowClearance);
    final arrow = (anchor - position).clamp(arrowClearance, lastCentre);
    if (arrowPosition.value != arrow) arrowPosition.value = arrow;
    return position;
  }

  @override
  bool shouldRelayout(PopoverTipLayoutDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.side != side ||
        oldDelegate.nearPhysicalStart != nearPhysicalStart ||
        oldDelegate.margin != margin ||
        oldDelegate.gap != gap ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.arrowInset != arrowInset ||
        oldDelegate.arrowClearance != arrowClearance ||
        oldDelegate.arrowPosition != arrowPosition;
  }
}
