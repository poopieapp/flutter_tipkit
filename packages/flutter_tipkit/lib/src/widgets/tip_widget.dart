import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/model/tip_group.dart';
import 'package:flutter_tipkit/src/widgets/tip_bubble.dart';
import 'package:flutter_tipkit/src/widgets/tip_card.dart';
import 'package:flutter_tipkit/src/widgets/tip_display.dart';
import 'package:flutter_tipkit/src/widgets/tip_theme.dart';
import 'package:flutter_tipkit/src/widgets/tip_transitions.dart';

export 'package:flutter_tipkit/src/widgets/tip_display.dart'
    show TipActionCallback, TipCloseCallback, TipContentResolver;

/// A tip shown inline, in the layout.
///
/// Takes no space while the tip may not be displayed, and grows in and
/// fades in when it may. Put the space around the tip in [padding], not in a
/// `Padding` around this widget, so it goes away with the tip.
///
/// ```dart
/// TipWidget(
///   tip: const FavoriteTip(),
///   padding: const EdgeInsets.only(bottom: 12),
/// )
/// ```
///
/// In a `CustomScrollView`, use [SliverTipWidget].
class TipWidget extends _InlineTipWidget {
  /// Shows [tip] when it may be displayed.
  ///
  /// With a [group] too, shows [tip] only while it is the group's current
  /// tip, so the tips of one group can show at different places.
  const TipWidget({
    required Tip super.tip,
    super.group,
    super.padding,
    super.content,
    super.leading,
    super.showCloseButton,
    super.arrowEdge,
    super.arrowAlignment,
    super.onAction,
    super.onClose,
    super.cardBuilder,
    super.transitionBuilder,
    super.key,
  });

  /// Shows the current tip of [group].
  const TipWidget.group(
    TipGroup group, {
    super.padding,
    super.content,
    super.leading,
    super.showCloseButton,
    super.arrowEdge,
    super.arrowAlignment,
    super.onAction,
    super.onClose,
    super.cardBuilder,
    super.transitionBuilder,
    super.key,
  }) : super(group: group);

  @override
  bool get _isSliver => false;
}

/// A [TipWidget] for a `CustomScrollView`: a sliver that has no extent while
/// the tip may not be displayed.
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverTipWidget(
///       tip: const FeedTip(),
///       padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
///     ),
///     SliverList(...),
///   ],
/// )
/// ```
class SliverTipWidget extends _InlineTipWidget {
  /// Shows [tip] when it may be displayed. See [TipWidget.new].
  const SliverTipWidget({
    required Tip super.tip,
    super.group,
    super.padding,
    super.content,
    super.leading,
    super.showCloseButton,
    super.arrowEdge,
    super.arrowAlignment,
    super.onAction,
    super.onClose,
    super.cardBuilder,
    super.transitionBuilder,
    super.key,
  });

  /// Shows the current tip of [group].
  const SliverTipWidget.group(
    TipGroup group, {
    super.padding,
    super.content,
    super.leading,
    super.showCloseButton,
    super.arrowEdge,
    super.arrowAlignment,
    super.onAction,
    super.onClose,
    super.cardBuilder,
    super.transitionBuilder,
    super.key,
  }) : super(group: group);

  @override
  bool get _isSliver => true;
}

/// What [TipWidget] and [SliverTipWidget] share.
abstract class _InlineTipWidget extends StatefulWidget {
  const _InlineTipWidget({
    this.tip,
    this.group,
    this.padding = EdgeInsets.zero,
    this.content,
    this.leading,
    this.showCloseButton,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.onAction,
    this.onClose,
    this.cardBuilder,
    this.transitionBuilder,
    super.key,
  });

  /// The tip to show.
  final Tip? tip;

  /// The group whose current tip to show.
  final TipGroup? group;

  /// Space around the tip, there only while the tip is: it grows in and out
  /// with the tip.
  final EdgeInsetsGeometry padding;

  /// Provides the content instead of `Tip.content`.
  final TipContentResolver? content;

  /// Replaces [TipThemeData.leading].
  final Widget? leading;

  /// Replaces [TipThemeData.showCloseButton].
  final bool? showCloseButton;

  /// The edge with an arrow pointing at what the tip is about. None by
  /// default.
  final TipArrowEdge? arrowEdge;

  /// Where along [arrowEdge] the arrow sits.
  final TipArrowAlignment arrowAlignment;

  /// Called after an action is tapped, and the tip invalidated if the action
  /// says so.
  final TipActionCallback? onAction;

  /// Called after the tip is closed and invalidated.
  final TipCloseCallback? onClose;

  /// Draws the tip instead of [TipThemeData.cardBuilder] or the default
  /// [TipCard].
  final TipCardBuilder? cardBuilder;

  /// Animates the tip instead of [TipThemeData.inlineTransitionBuilder].
  final TipTransitionBuilder? transitionBuilder;

  bool get _isSliver;

  @override
  State<_InlineTipWidget> createState() => _InlineTipWidgetState();
}

class _InlineTipWidgetState extends State<_InlineTipWidget>
    with SingleTickerProviderStateMixin, TipDisplayStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeInOut,
  );

  /// The tip this widget reports as displayed.
  Tip? _shown;

  /// The tip to render, kept while it animates out.
  Tip? _rendered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = TipTheme.of(context);
    _animation.duration = theme.transitionDuration;
    _curved.curve = theme.transitionCurve;
  }

  @override
  void didUpdateWidget(_InlineTipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tip != widget.tip || oldWidget.group != widget.group) {
      scheduleTipSync();
    }
  }

  @override
  void syncTipDisplay() {
    final target = resolveTipForHost(tip: widget.tip, group: widget.group);
    if (target == _shown) return;
    final previous = _shown;
    _shown = target;
    if (previous != null) Tips.center.endDisplay(previous);
    if (target != null) {
      Tips.center.beginDisplay(target);
      _rendered = target;
      _animation.forward();
    } else if (isHostVisible) {
      _animation.reverse();
    } else {
      // Tickers are off when the widget is not visible, so an exit
      // animation would never end.
      _animation.value = 0;
    }
    setState(() {});
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _shown == null && mounted) {
      setState(() => _rendered = null);
    }
  }

  @override
  void dispose() {
    final shown = _shown;
    if (shown != null) Tips.center.endDisplay(shown);
    _curved.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _rendered;
    if (tip == null) {
      return widget._isSliver
          ? const SliverToBoxAdapter()
          : const SizedBox.shrink();
    }
    final theme = TipTheme.of(context);
    final details = TipCardDetails(
      tip: tip,
      content: widget.content?.call(context, tip) ?? tip.content,
      isPopover: false,
      leading: widget.leading,
      showCloseButton: widget.showCloseButton,
      arrowEdge: widget.arrowEdge,
      arrowAlignment: widget.arrowAlignment,
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
        widget.transitionBuilder ?? theme.inlineTransitionBuilder;
    final revealed = IgnorePointer(
      ignoring: _shown == null,
      child: transition(
        context,
        _curved,
        const TipTransitionDetails(isPopover: false),
        Padding(
          padding: widget.padding,
          child: AnimatedSize(
            duration: theme.transitionDuration,
            curve: theme.transitionCurve,
            alignment: Alignment.topCenter,
            child: card,
          ),
        ),
      ),
    );
    return widget._isSliver ? SliverToBoxAdapter(child: revealed) : revealed;
  }
}
