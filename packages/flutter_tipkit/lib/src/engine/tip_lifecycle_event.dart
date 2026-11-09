import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/model/tip.dart';

/// Something that happened to a tip, reported to the `onEvent` callback of
/// `Tips.configure`, for example to log it to analytics.
@immutable
sealed class TipLifecycleEvent {
  const TipLifecycleEvent(this.tip);

  /// The tip it happened to.
  final Tip tip;
}

/// The tip appeared on screen.
final class TipShownEvent extends TipLifecycleEvent {
  /// Creates the event.
  const TipShownEvent(super.tip, {required this.displayCount});

  /// How many times the tip has been displayed, this time included.
  final int displayCount;
}

/// The user tapped one of the tip's actions.
final class TipActionEvent extends TipLifecycleEvent {
  /// Creates the event.
  const TipActionEvent(super.tip, this.action);

  /// The action that was tapped.
  final TipAction action;
}

/// The tip was invalidated and will not be displayed again.
final class TipInvalidatedEvent extends TipLifecycleEvent {
  /// Creates the event.
  const TipInvalidatedEvent(super.tip, this.reason);

  /// Why the tip was invalidated.
  final TipInvalidationReason reason;
}
