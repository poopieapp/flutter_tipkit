import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/model/tip_option.dart';
import 'package:flutter_tipkit/src/model/tip_rule.dart';

/// A contextual tip.
///
/// A tip is a plain model. It knows its [id], what it says ([content]), when
/// it may show ([rules]) and how ([options]), but nothing about how it looks:
/// that is the job of `TipWidget`, `PopoverTipWidget` and `TipTheme`.
///
/// ```dart
/// class FavoriteTip extends Tip {
///   const FavoriteTip();
///
///   @override
///   String get id => 'favorite';
///
///   @override
///   TipContent get content => const TipContent(
///         title: 'Save as favorite',
///         message: 'Tap the star to find this place again later.',
///       );
/// }
/// ```
///
/// Tips are compared by [id], so two instances with the same id are the same
/// tip. The id is persisted: never change it once a tip has shipped.
@immutable
abstract class Tip {
  /// Lets subclasses be `const`.
  const Tip();

  /// The stable identifier the tip's state is stored under.
  String get id;

  /// What the tip says.
  ///
  /// Read each time the tip is rendered, so localization that needs no
  /// `BuildContext` (for example `easy_localization`'s `.tr()` or
  /// `Intl.message`) can be used here directly. With context-based
  /// localization, pass the content where the tip is shown instead.
  TipContent get content;

  /// The conditions that must all hold for the tip to become available.
  ///
  /// Empty by default: the tip is available as soon as tips are configured.
  List<TipRule> get rules => const [];

  /// Options that change how the tip is displayed.
  List<TipOption> get options => const [];

  @override
  bool operator ==(Object other) => other is Tip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tip($id)';
}

/// The text of a tip and the actions it offers.
@immutable
class TipContent {
  /// Creates the content of a tip.
  const TipContent({
    required this.title,
    this.message,
    this.actions = const [],
  });

  /// The short headline of the tip.
  final String title;

  /// The optional longer explanation below the [title].
  final String? message;

  /// The buttons shown at the bottom of the tip, in order.
  final List<TipAction> actions;

  @override
  bool operator ==(Object other) =>
      other is TipContent &&
      other.title == title &&
      other.message == message &&
      listEquals(other.actions, actions);

  @override
  int get hashCode => Object.hash(title, message, Object.hashAll(actions));
}

/// A button on a tip, such as "Next" or "Got it".
@immutable
class TipAction {
  /// Creates an action with a stable [id] and a visible [label].
  const TipAction({
    required this.id,
    required this.label,
    this.invalidatesTip = true,
  });

  /// Identifies the action in callbacks and analytics events.
  final String id;

  /// The text on the button.
  final String label;

  /// Whether tapping the action invalidates the tip with
  /// `TipInvalidationReason.actionPerformed`, so it does not show again.
  ///
  /// Most tip actions ("Next", "Got it") end the tip, so this is the default.
  final bool invalidatesTip;

  @override
  bool operator ==(Object other) =>
      other is TipAction &&
      other.id == id &&
      other.label == label &&
      other.invalidatesTip == invalidatesTip;

  @override
  int get hashCode => Object.hash(id, label, invalidatesTip);
}

/// Why a tip was invalidated.
enum TipInvalidationReason {
  /// The user did what the tip suggested, or tapped one of its actions.
  actionPerformed,

  /// The user closed the tip.
  tipClosed,

  /// The tip was displayed as many times as its
  /// `TipOption.maxDisplayCount` allows.
  displayCountExceeded,
}

/// Whether a tip may currently be displayed.
@immutable
sealed class TipStatus {
  const TipStatus();

  /// The tip is waiting: tips are not configured yet, or a rule does not hold.
  static const TipStatus pending = TipPending._();

  /// Every rule holds and the tip has not been invalidated.
  static const TipStatus available = TipAvailable._();

  /// Whether this is [available].
  bool get isAvailable => this is TipAvailable;
}

/// See [TipStatus.pending].
final class TipPending extends TipStatus {
  const TipPending._();

  @override
  String toString() => 'TipStatus.pending';
}

/// See [TipStatus.available].
final class TipAvailable extends TipStatus {
  const TipAvailable._();

  @override
  String toString() => 'TipStatus.available';
}

/// The tip will not be displayed again, for [reason].
final class TipInvalidated extends TipStatus {
  /// Creates the invalidated status.
  const TipInvalidated(this.reason);

  /// Why the tip was invalidated.
  final TipInvalidationReason reason;

  @override
  bool operator ==(Object other) =>
      other is TipInvalidated && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'TipStatus.invalidated(${reason.name})';
}
