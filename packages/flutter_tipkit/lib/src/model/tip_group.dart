import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';
import 'package:flutter_tipkit/src/model/tip.dart';

/// How a [TipGroup] picks its current tip.
enum TipGroupPriority {
  /// The tips show one after another: a tip shows only once every tip before
  /// it has been invalidated.
  ordered,

  /// The first available tip shows, in the order given.
  firstAvailable,
}

/// Tips shown one at a time.
///
/// The group keeps no state of its own: which tip is current follows from the
/// tips' own stored state, so the order can be chosen at runtime (for example
/// from remote config) and the group still resumes where the user left off.
///
/// ```dart
/// final onboarding = TipGroup.ordered([WelcomeTip(), AddItemTip()]);
///
/// TipWidget.group(onboarding);
/// ```
@immutable
class TipGroup {
  /// Creates a group of [tips] that picks its current tip by [priority].
  const TipGroup(this.tips, {this.priority = TipGroupPriority.ordered});

  /// Creates a group whose [tips] show one after another.
  const TipGroup.ordered(this.tips) : priority = TipGroupPriority.ordered;

  /// Creates a group that shows the first available of its [tips].
  const TipGroup.firstAvailable(this.tips)
    : priority = TipGroupPriority.firstAvailable;

  /// The tips in the group, in order.
  final List<Tip> tips;

  /// How the group picks its current tip.
  final TipGroupPriority priority;

  /// The tip the group shows now, if any.
  Tip? get currentTip => Tips.center.currentTipOf(this);

  /// Whether every tip in the group has been invalidated.
  bool get isCompleted =>
      tips.every((tip) => Tips.center.status(tip) is TipInvalidated);

  @override
  bool operator ==(Object other) =>
      other is TipGroup &&
      other.priority == priority &&
      listEquals(other.tips, tips);

  @override
  int get hashCode => Object.hash(priority, Object.hashAll(tips));
}
