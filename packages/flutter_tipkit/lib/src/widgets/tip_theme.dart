import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/widgets/tip_bubble.dart';
import 'package:flutter_tipkit/src/widgets/tip_card.dart';
import 'package:flutter_tipkit/src/widgets/tip_transitions.dart';

/// Builds the button for one action of a tip.
///
/// [onPressed] invalidates the tip if the action says so and calls the
/// widget's `onAction`.
typedef TipActionBuilder =
    Widget Function(
      BuildContext context,
      TipAction action,
      VoidCallback onPressed,
    );

/// Builds the close button of a tip. [onClose] invalidates the tip with
/// `TipInvalidationReason.tipClosed`.
typedef TipCloseButtonBuilder =
    Widget Function(BuildContext context, VoidCallback onClose);

/// How tips look and move, set for a subtree with [TipTheme].
///
/// Three levels of customization, from light to full:
///
/// - The colors, [borderSide], [borderRadius], [arrowShape], text styles and
///   spacing restyle the default [TipCard].
/// - [actionBuilder], [closeButtonBuilder] and [leading] replace parts of it.
/// - [cardBuilder] replaces it entirely, while the tip widgets still decide
///   when it shows, place popovers and animate it.
///
/// [inlineTransitionBuilder] and [popoverTransitionBuilder] replace the
/// animations. The defaults use no design system, so they work in Material,
/// Cupertino and custom apps alike. Text styles are merged onto the
/// surrounding `DefaultTextStyle`.
@immutable
class TipThemeData {
  /// Creates a theme. Every argument has a default.
  const TipThemeData({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gradient,
    this.borderSide = const BorderSide(color: Color(0x1F000000)),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.inlineShadows = const [],
    this.popoverShadows = const [
      BoxShadow(color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 4)),
    ],
    this.padding = const EdgeInsets.all(16),
    this.titleStyle = const TextStyle(fontWeight: FontWeight.w600),
    this.messageStyle = const TextStyle(color: Color(0xFF6B6B6B)),
    this.actionStyle = const TextStyle(
      color: Color(0xFF007AFF),
      fontWeight: FontWeight.w600,
    ),
    this.messageSpacing = 2,
    this.leading,
    this.leadingSpacing = 12,
    this.showCloseButton = true,
    this.closeButtonBuilder,
    this.closeButtonLabel = 'Close',
    this.actionBuilder,
    this.actionDividerColor = const Color(0x1F000000),
    this.arrowShape = const TipArrowShape.triangle(),
    this.arrowInset = 24,
    this.cardBuilder,
    this.inlineTransitionBuilder = TipTransitions.reveal,
    this.popoverTransitionBuilder = TipTransitions.scale,
    this.transitionDuration = const Duration(milliseconds: 200),
    this.transitionCurve = Curves.easeInOut,
    this.popoverMaxWidth = 360,
    this.popoverMaxWidthFactor = 0.9,
    this.popoverMargin = const EdgeInsets.all(8),
    this.popoverGap = 4,
    this.barrierColor = const Color(0x00000000),
  });

  /// The fill of the tip, unless [gradient] is set.
  final Color backgroundColor;

  /// A gradient fill of the tip, instead of [backgroundColor].
  final Gradient? gradient;

  /// The outline of the tip, arrow included. [BorderSide.none] draws none.
  final BorderSide borderSide;

  /// The rounding of the tip's corners.
  final BorderRadiusGeometry borderRadius;

  /// The shadows under inline tips. None by default.
  final List<BoxShadow> inlineShadows;

  /// The shadows under popover tips.
  final List<BoxShadow> popoverShadows;

  /// The space between the edge of the tip and its content.
  final EdgeInsets padding;

  /// The style of the title, merged onto the surrounding text style.
  final TextStyle titleStyle;

  /// The style of the message, merged onto the surrounding text style.
  final TextStyle messageStyle;

  /// The style of the default action buttons.
  final TextStyle actionStyle;

  /// The space between the title and the message.
  final double messageSpacing;

  /// Shown before the text of every tip, such as an icon. None by default.
  final Widget? leading;

  /// The space between [leading] and the text.
  final double leadingSpacing;

  /// Whether tips show a close button by default.
  final bool showCloseButton;

  /// Builds the close button. A drawn cross by default.
  final TipCloseButtonBuilder? closeButtonBuilder;

  /// What screen readers announce for the default close button. Set it to
  /// the translated word in localized apps.
  final String closeButtonLabel;

  /// Builds each action button. Full-width text by default.
  final TipActionBuilder? actionBuilder;

  /// The line above each action.
  final Color actionDividerColor;

  /// What the arrow looks like, including its size.
  final TipArrowShape arrowShape;

  /// How far the arrow's centre is from the tip's corner when the arrow is
  /// aligned to the start or end of an edge.
  final double arrowInset;

  /// Draws the whole tip instead of the default [TipCard].
  final TipCardBuilder? cardBuilder;

  /// Animates inline tips in and out. Grows them in by default.
  final TipTransitionBuilder inlineTransitionBuilder;

  /// Animates popover tips in and out. Scales them up from the arrow by
  /// default.
  final TipTransitionBuilder popoverTransitionBuilder;

  /// How long tips take to appear and disappear.
  final Duration transitionDuration;

  /// The curve tips appear and disappear with.
  final Curve transitionCurve;

  /// The widest a popover tip gets.
  final double popoverMaxWidth;

  /// The widest a popover tip gets, as a fraction of the screen width.
  final double popoverMaxWidthFactor;

  /// The least space between a popover tip and the screen edge, on top of
  /// the system padding.
  final EdgeInsets popoverMargin;

  /// The space between a popover's arrow and its target.
  final double popoverGap;

  /// The color over the rest of the screen while a popover tip shows.
  final Color barrierColor;

  /// The outline of a tip in this theme, with its arrow on [arrowSide].
  TipBubbleBorder bubbleBorder({
    TipSide? arrowSide,
    bool? arrowNearPhysicalStart,
  }) {
    return TipBubbleBorder(
      side: borderSide,
      borderRadius: borderRadius,
      arrowSide: arrowSide,
      arrowShape: arrowShape,
      arrowNearPhysicalStart: arrowNearPhysicalStart,
      arrowInset: arrowInset,
    );
  }

  /// A copy with the given fields replaced.
  TipThemeData copyWith({
    Color? backgroundColor,
    Gradient? gradient,
    BorderSide? borderSide,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? inlineShadows,
    List<BoxShadow>? popoverShadows,
    EdgeInsets? padding,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    TextStyle? actionStyle,
    double? messageSpacing,
    Widget? leading,
    double? leadingSpacing,
    bool? showCloseButton,
    TipCloseButtonBuilder? closeButtonBuilder,
    String? closeButtonLabel,
    TipActionBuilder? actionBuilder,
    Color? actionDividerColor,
    TipArrowShape? arrowShape,
    double? arrowInset,
    TipCardBuilder? cardBuilder,
    TipTransitionBuilder? inlineTransitionBuilder,
    TipTransitionBuilder? popoverTransitionBuilder,
    Duration? transitionDuration,
    Curve? transitionCurve,
    double? popoverMaxWidth,
    double? popoverMaxWidthFactor,
    EdgeInsets? popoverMargin,
    double? popoverGap,
    Color? barrierColor,
  }) {
    return TipThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gradient: gradient ?? this.gradient,
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      inlineShadows: inlineShadows ?? this.inlineShadows,
      popoverShadows: popoverShadows ?? this.popoverShadows,
      padding: padding ?? this.padding,
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      actionStyle: actionStyle ?? this.actionStyle,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      leading: leading ?? this.leading,
      leadingSpacing: leadingSpacing ?? this.leadingSpacing,
      showCloseButton: showCloseButton ?? this.showCloseButton,
      closeButtonBuilder: closeButtonBuilder ?? this.closeButtonBuilder,
      closeButtonLabel: closeButtonLabel ?? this.closeButtonLabel,
      actionBuilder: actionBuilder ?? this.actionBuilder,
      actionDividerColor: actionDividerColor ?? this.actionDividerColor,
      arrowShape: arrowShape ?? this.arrowShape,
      arrowInset: arrowInset ?? this.arrowInset,
      cardBuilder: cardBuilder ?? this.cardBuilder,
      inlineTransitionBuilder:
          inlineTransitionBuilder ?? this.inlineTransitionBuilder,
      popoverTransitionBuilder:
          popoverTransitionBuilder ?? this.popoverTransitionBuilder,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
      popoverMaxWidth: popoverMaxWidth ?? this.popoverMaxWidth,
      popoverMaxWidthFactor:
          popoverMaxWidthFactor ?? this.popoverMaxWidthFactor,
      popoverMargin: popoverMargin ?? this.popoverMargin,
      popoverGap: popoverGap ?? this.popoverGap,
      barrierColor: barrierColor ?? this.barrierColor,
    );
  }

  /// Interpolates between [a] and [b]. Values that cannot be interpolated
  /// switch halfway.
  // Static like `ThemeData.lerp` and the other theme lerps in Flutter.
  // ignore: prefer_constructors_over_static_methods
  static TipThemeData lerp(TipThemeData a, TipThemeData b, double t) {
    if (identical(a, b)) return a;
    final other = t < 0.5 ? a : b;
    return TipThemeData(
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t)!,
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
      borderRadius: BorderRadiusGeometry.lerp(
        a.borderRadius,
        b.borderRadius,
        t,
      )!,
      inlineShadows:
          BoxShadow.lerpList(a.inlineShadows, b.inlineShadows, t) ?? const [],
      popoverShadows:
          BoxShadow.lerpList(a.popoverShadows, b.popoverShadows, t) ?? const [],
      padding: EdgeInsets.lerp(a.padding, b.padding, t)!,
      titleStyle: TextStyle.lerp(a.titleStyle, b.titleStyle, t)!,
      messageStyle: TextStyle.lerp(a.messageStyle, b.messageStyle, t)!,
      actionStyle: TextStyle.lerp(a.actionStyle, b.actionStyle, t)!,
      messageSpacing: lerpDouble(a.messageSpacing, b.messageSpacing, t)!,
      leading: other.leading,
      leadingSpacing: lerpDouble(a.leadingSpacing, b.leadingSpacing, t)!,
      showCloseButton: other.showCloseButton,
      closeButtonBuilder: other.closeButtonBuilder,
      closeButtonLabel: other.closeButtonLabel,
      actionBuilder: other.actionBuilder,
      actionDividerColor: Color.lerp(
        a.actionDividerColor,
        b.actionDividerColor,
        t,
      )!,
      arrowShape: other.arrowShape,
      arrowInset: lerpDouble(a.arrowInset, b.arrowInset, t)!,
      cardBuilder: other.cardBuilder,
      inlineTransitionBuilder: other.inlineTransitionBuilder,
      popoverTransitionBuilder: other.popoverTransitionBuilder,
      transitionDuration: other.transitionDuration,
      transitionCurve: other.transitionCurve,
      popoverMaxWidth: lerpDouble(a.popoverMaxWidth, b.popoverMaxWidth, t)!,
      popoverMaxWidthFactor: lerpDouble(
        a.popoverMaxWidthFactor,
        b.popoverMaxWidthFactor,
        t,
      )!,
      popoverMargin: EdgeInsets.lerp(a.popoverMargin, b.popoverMargin, t)!,
      popoverGap: lerpDouble(a.popoverGap, b.popoverGap, t)!,
      barrierColor: Color.lerp(a.barrierColor, b.barrierColor, t)!,
    );
  }

  List<Object?> get _props => [
    backgroundColor,
    gradient,
    borderSide,
    borderRadius,
    Object.hashAll(inlineShadows),
    Object.hashAll(popoverShadows),
    padding,
    titleStyle,
    messageStyle,
    actionStyle,
    messageSpacing,
    leading,
    leadingSpacing,
    showCloseButton,
    closeButtonBuilder,
    closeButtonLabel,
    actionBuilder,
    actionDividerColor,
    arrowShape,
    arrowInset,
    cardBuilder,
    inlineTransitionBuilder,
    popoverTransitionBuilder,
    transitionDuration,
    transitionCurve,
    popoverMaxWidth,
    popoverMaxWidthFactor,
    popoverMargin,
    popoverGap,
    barrierColor,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! TipThemeData) return false;
    final mine = _props;
    final theirs = other._props;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);
}

/// Sets the [TipThemeData] for the tips below it.
class TipTheme extends InheritedTheme {
  /// Applies [data] to the tips in [child].
  const TipTheme({required this.data, required super.child, super.key});

  /// The look of the tips below.
  final TipThemeData data;

  /// The closest theme above [context], or the defaults.
  static TipThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<TipTheme>();
    return theme?.data ?? const TipThemeData();
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return TipTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(TipTheme oldWidget) => data != oldWidget.data;
}
