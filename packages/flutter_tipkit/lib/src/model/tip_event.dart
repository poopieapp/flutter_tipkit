import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';

/// Something the user does that tip rules can count.
///
/// ```dart
/// const addedItem = TipEvent('addedItem');
///
/// // Each time it happens:
/// addedItem.donate();
///
/// // In a tip:
/// @override
/// List<TipRule> get rules => [
///       TipRule.event(addedItem, (d) => d.today >= 3),
///     ];
/// ```
@immutable
class TipEvent {
  /// Creates an event stored under [id].
  const TipEvent(this.id);

  /// The stable identifier the donations are stored under.
  final String id;

  /// Records that the event happened now, and re-evaluates the tips.
  void donate() => Tips.center.donate(this);

  /// Every recorded donation of this event.
  TipEventDonations get donations => Tips.center.donations(this);

  @override
  bool operator ==(Object other) => other is TipEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TipEvent($id)';
}

/// The recorded donations of a [TipEvent], oldest first.
@immutable
class TipEventDonations {
  /// Creates the donations, as seen at [now].
  TipEventDonations(Iterable<DateTime> dates, {required this.now})
    : dates = List.unmodifiable(dates);

  /// When each donation happened, oldest first.
  final List<DateTime> dates;

  /// The time the donations are evaluated at.
  final DateTime now;

  /// How many times the event was donated.
  int get count => dates.length;

  /// When the event was last donated, if ever.
  DateTime? get last => dates.isEmpty ? null : dates.last;

  /// How many times the event was donated in the last [window].
  int within(Duration window) {
    final since = now.subtract(window);
    return dates.where((date) => !date.isBefore(since)).length;
  }

  /// How many times the event was donated on the same calendar day as [now].
  int get today {
    return dates
        .where(
          (date) =>
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
        )
        .length;
  }
}
