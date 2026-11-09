import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/widgets/tip_bubble.dart';
import 'package:flutter_tipkit/src/widgets/tip_theme.dart';

/// Everything a [TipCardBuilder] needs to draw a tip.
@immutable
class TipCardDetails {
  /// Creates the details.
  const TipCardDetails({
    required this.tip,
    required this.content,
    required this.onAction,
    required this.onClose,
    required this.isPopover,
    this.leading,
    this.showCloseButton,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.arrowPosition,
  });

  /// The tip being shown.
  final Tip tip;

  /// What it says: the tip's content, or the one given where it is shown.
  final TipContent content;

  /// Call with an action when it is tapped. Reports it, invalidates the tip
  /// if the action says so, and calls the widget's `onAction`.
  final ValueChanged<TipAction> onAction;

  /// Call when the tip is closed. Invalidates the tip with
  /// `TipInvalidationReason.tipClosed` and calls the widget's `onClose`.
  final VoidCallback onClose;

  /// Whether the tip is a popover, rather than inline in the layout.
  final bool isPopover;

  /// The leading widget given where the tip is shown, if any.
  final Widget? leading;

  /// Whether the close button should show, if given where the tip is shown.
  final bool? showCloseButton;

  /// The edge that should carry the arrow, if any. For a popover it faces
  /// the target.
  final TipArrowEdge? arrowEdge;

  /// Where along [arrowEdge] the arrow sits.
  final TipArrowAlignment arrowAlignment;

  /// For a popover, the arrow's centre along [arrowEdge] once it is laid
  /// out, so the arrow keeps pointing at the target when the tip is shifted
  /// to stay on screen. Pass it to a [TipBubble] to get this for free.
  final ValueListenable<double?>? arrowPosition;
}

/// Builds the look of a tip from [details], replacing [TipCard].
///
/// The tip widgets still decide when the tip shows, place popovers and run
/// the transitions; the builder only draws the tip. Return
/// `TipCard.fromDetails(details)` to wrap or keep the default.
typedef TipCardBuilder =
    Widget Function(BuildContext context, TipCardDetails details);

/// The look of a tip: a [TipBubble] holding a [TipContentLayout].
///
/// `TipWidget`, `SliverTipWidget` and `PopoverTipWidget` show it when the tip
/// may be displayed, unless a [TipCardBuilder] replaces it. Use it directly
/// to show a tip's look without the tip system, for example in a design
/// catalogue.
class TipCard extends StatelessWidget {
  /// Creates the look of a tip with [content].
  const TipCard({
    required this.content,
    this.onAction,
    this.onClose,
    this.leading,
    this.showCloseButton,
    this.arrowEdge,
    this.arrowAlignment = TipArrowAlignment.center,
    this.arrowPosition,
    this.isPopover = false,
    super.key,
  });

  /// Creates the default look of the tip described by [details].
  TipCard.fromDetails(TipCardDetails details, {Key? key})
    : this(
        content: details.content,
        onAction: details.onAction,
        onClose: details.onClose,
        leading: details.leading,
        showCloseButton: details.showCloseButton,
        arrowEdge: details.arrowEdge,
        arrowAlignment: details.arrowAlignment,
        arrowPosition: details.arrowPosition,
        isPopover: details.isPopover,
        key: key,
      );

  /// What the tip says.
  final TipContent content;

  /// Called when an action is tapped.
  final ValueChanged<TipAction>? onAction;

  /// Called when the close button is tapped.
  final VoidCallback? onClose;

  /// Replaces [TipThemeData.leading].
  final Widget? leading;

  /// Replaces [TipThemeData.showCloseButton].
  final bool? showCloseButton;

  /// See [TipBubble.arrowEdge].
  final TipArrowEdge? arrowEdge;

  /// See [TipBubble.arrowAlignment].
  final TipArrowAlignment arrowAlignment;

  /// See [TipBubble.arrowPosition].
  final ValueListenable<double?>? arrowPosition;

  /// Whether to draw [TipThemeData.popoverShadows] rather than
  /// [TipThemeData.inlineShadows].
  final bool isPopover;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    final padding = content.actions.isEmpty
        ? theme.padding
        : theme.padding.copyWith(bottom: 0);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: TipBubble(
        arrowEdge: arrowEdge,
        arrowAlignment: arrowAlignment,
        arrowPosition: arrowPosition,
        shadows: isPopover ? theme.popoverShadows : theme.inlineShadows,
        child: Padding(
          padding: padding,
          child: TipContentLayout(
            content: content,
            leading: leading ?? theme.leading,
            onAction: onAction,
            onClose: (showCloseButton ?? theme.showCloseButton)
                ? onClose
                : null,
          ),
        ),
      ),
    );
  }
}

/// The inside of a tip: the leading widget, title, message, close button and
/// actions.
class TipContentLayout extends StatelessWidget {
  /// Lays out [content].
  const TipContentLayout({
    required this.content,
    this.leading,
    this.onAction,
    this.onClose,
    super.key,
  });

  /// What the tip says.
  final TipContent content;

  /// Shown before the text, such as an icon.
  final Widget? leading;

  /// Called when an action is tapped.
  final ValueChanged<TipAction>? onAction;

  /// Called when the close button is tapped. Null hides the close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final message = content.message;
    final onClose = this.onClose;
    final leading = this.leading;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                content.title,
                style: baseStyle.merge(theme.titleStyle),
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 8),
              theme.closeButtonBuilder?.call(context, onClose) ??
                  TipCloseButton(onClose: onClose),
            ],
          ],
        ),
        if (message != null) ...[
          SizedBox(height: theme.messageSpacing),
          Text(message, style: baseStyle.merge(theme.messageStyle)),
        ],
        if (content.actions.isNotEmpty)
          TipActionBar(actions: content.actions, onAction: onAction),
      ],
    );
    if (leading == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        SizedBox(width: theme.leadingSpacing),
        Expanded(child: text),
      ],
    );
  }
}

/// The actions at the bottom of a tip, each below a dividing line.
class TipActionBar extends StatelessWidget {
  /// Lays out [actions].
  const TipActionBar({required this.actions, this.onAction, super.key});

  /// The actions, in order.
  final List<TipAction> actions;

  /// Called when an action is tapped.
  final ValueChanged<TipAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (final action in actions) ...[
          ColoredBox(
            color: theme.actionDividerColor,
            child: const SizedBox(height: 1),
          ),
          theme.actionBuilder?.call(
                context,
                action,
                () => onAction?.call(action),
              ) ??
              TipActionButton(
                action: action,
                onPressed: () => onAction?.call(action),
              ),
        ],
      ],
    );
  }
}

/// The default button for a [TipAction]: its label, full width.
class TipActionButton extends StatelessWidget {
  /// Creates the button.
  const TipActionButton({
    required this.action,
    required this.onPressed,
    super.key,
  });

  /// The action the button performs.
  final TipAction action;

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            action.label,
            style: DefaultTextStyle.of(context).style.merge(theme.actionStyle),
          ),
        ),
      ),
    );
  }
}

/// The default close button of a tip: a small drawn cross.
class TipCloseButton extends StatelessWidget {
  /// Creates the button.
  const TipCloseButton({required this.onClose, super.key});

  /// Called when the button is tapped.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = TipTheme.of(context);
    final color =
        theme.messageStyle.color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF6B6B6B);
    return Semantics(
      button: true,
      label: theme.closeButtonLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SizedBox.square(
          dimension: 24,
          child: Center(
            child: CustomPaint(
              size: const Size.square(10),
              painter: _CrossPainter(color),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}
