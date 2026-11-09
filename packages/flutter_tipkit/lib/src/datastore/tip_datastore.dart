import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/datastore/in_memory_tip_datastore.dart';
import 'package:flutter_tipkit/src/model/tip.dart';

/// Where tip state is persisted.
///
/// Implement it to keep tips in any storage: shared preferences (see the
/// `flutter_tipkit_shared_preferences` package), a database, or a backend
/// that syncs tips across devices. [InMemoryTipDatastore] keeps nothing
/// between launches and is the default.
///
/// The engine keeps all state in memory and calls the write methods one at a
/// time, in order, without waiting for them before updating the UI. Every
/// value passed to the write methods is JSON-encodable.
abstract interface class TipDatastore {
  /// Reads everything stored. Called once, by `Tips.configure`.
  Future<TipStoreSnapshot> load();

  /// Stores the [record] of the tip with [tipId], or deletes it when null.
  Future<void> writeTip(String tipId, TipRecord? record);

  /// Stores the [value] of the parameter with [parameterId].
  Future<void> writeParameter(String parameterId, Object? value);

  /// Stores the donation times of the event with [eventId].
  Future<void> writeEvent(String eventId, List<DateTime> donations);

  /// Stores the state shared by all tips.
  Future<void> writeGlobal(TipGlobalRecord record);

  /// Deletes everything stored.
  Future<void> clear();
}

/// Everything a [TipDatastore] has stored.
@immutable
class TipStoreSnapshot {
  /// Creates a snapshot.
  const TipStoreSnapshot({
    this.tips = const {},
    this.parameters = const {},
    this.events = const {},
    this.global = const TipGlobalRecord(),
  });

  /// The record of each tip, by tip id.
  final Map<String, TipRecord> tips;

  /// The stored value of each parameter, by parameter id.
  final Map<String, Object?> parameters;

  /// The donation times of each event, by event id, oldest first.
  final Map<String, List<DateTime>> events;

  /// The state shared by all tips.
  final TipGlobalRecord global;
}

/// What is stored about one tip.
@immutable
class TipRecord {
  /// Creates a record.
  const TipRecord({
    this.displayCount = 0,
    this.firstDisplayedAt,
    this.lastDisplayedAt,
    this.invalidatedAt,
    this.invalidationReason,
  });

  /// Reads a record written by [toJson].
  factory TipRecord.fromJson(Map<String, Object?> json) {
    final reason = json['invalidationReason'];
    return TipRecord(
      displayCount: (json['displayCount'] as num?)?.toInt() ?? 0,
      firstDisplayedAt: _dateFromJson(json['firstDisplayedAt']),
      lastDisplayedAt: _dateFromJson(json['lastDisplayedAt']),
      invalidatedAt: _dateFromJson(json['invalidatedAt']),
      invalidationReason: reason is String
          ? TipInvalidationReason.values.asNameMap()[reason]
          : null,
    );
  }

  /// How many times the tip has been displayed.
  final int displayCount;

  /// When the tip was first displayed.
  final DateTime? firstDisplayedAt;

  /// When the tip was last displayed.
  final DateTime? lastDisplayedAt;

  /// When the tip was invalidated, if it was.
  final DateTime? invalidatedAt;

  /// Why the tip was invalidated, if it was.
  final TipInvalidationReason? invalidationReason;

  /// Whether the tip was invalidated.
  bool get isInvalidated => invalidationReason != null;

  /// A copy with the given fields replaced.
  TipRecord copyWith({
    int? displayCount,
    DateTime? firstDisplayedAt,
    DateTime? lastDisplayedAt,
    DateTime? invalidatedAt,
    TipInvalidationReason? invalidationReason,
  }) {
    return TipRecord(
      displayCount: displayCount ?? this.displayCount,
      firstDisplayedAt: firstDisplayedAt ?? this.firstDisplayedAt,
      lastDisplayedAt: lastDisplayedAt ?? this.lastDisplayedAt,
      invalidatedAt: invalidatedAt ?? this.invalidatedAt,
      invalidationReason: invalidationReason ?? this.invalidationReason,
    );
  }

  /// A JSON-encodable form of the record.
  Map<String, Object?> toJson() => {
    'displayCount': displayCount,
    if (firstDisplayedAt != null)
      'firstDisplayedAt': firstDisplayedAt!.millisecondsSinceEpoch,
    if (lastDisplayedAt != null)
      'lastDisplayedAt': lastDisplayedAt!.millisecondsSinceEpoch,
    if (invalidatedAt != null)
      'invalidatedAt': invalidatedAt!.millisecondsSinceEpoch,
    if (invalidationReason != null)
      'invalidationReason': invalidationReason!.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TipRecord &&
      other.displayCount == displayCount &&
      other.firstDisplayedAt == firstDisplayedAt &&
      other.lastDisplayedAt == lastDisplayedAt &&
      other.invalidatedAt == invalidatedAt &&
      other.invalidationReason == invalidationReason;

  @override
  int get hashCode => Object.hash(
    displayCount,
    firstDisplayedAt,
    lastDisplayedAt,
    invalidatedAt,
    invalidationReason,
  );

  @override
  String toString() => 'TipRecord(${toJson()})';
}

/// What is stored about all tips together, for the display frequency.
@immutable
class TipGlobalRecord {
  /// Creates a record.
  const TipGlobalRecord({this.lastNewTipId, this.lastNewTipShownAt});

  /// Reads a record written by [toJson].
  factory TipGlobalRecord.fromJson(Map<String, Object?> json) {
    final id = json['lastNewTipId'];
    return TipGlobalRecord(
      lastNewTipId: id is String ? id : null,
      lastNewTipShownAt: _dateFromJson(json['lastNewTipShownAt']),
    );
  }

  /// The tip that was last displayed for the first time.
  final String? lastNewTipId;

  /// When [lastNewTipId] was first displayed.
  final DateTime? lastNewTipShownAt;

  /// A JSON-encodable form of the record.
  Map<String, Object?> toJson() => {
    if (lastNewTipId != null) 'lastNewTipId': lastNewTipId,
    if (lastNewTipShownAt != null)
      'lastNewTipShownAt': lastNewTipShownAt!.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is TipGlobalRecord &&
      other.lastNewTipId == lastNewTipId &&
      other.lastNewTipShownAt == lastNewTipShownAt;

  @override
  int get hashCode => Object.hash(lastNewTipId, lastNewTipShownAt);
}

DateTime? _dateFromJson(Object? value) {
  return value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
      : null;
}
