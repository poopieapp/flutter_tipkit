import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/datastore/in_memory_tip_datastore.dart';
import 'package:flutter_tipkit/src/datastore/tip_datastore.dart';
import 'package:flutter_tipkit/src/engine/tip_display_frequency.dart';
import 'package:flutter_tipkit/src/engine/tip_lifecycle_event.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/model/tip_event.dart';
import 'package:flutter_tipkit/src/model/tip_group.dart';
import 'package:flutter_tipkit/src/model/tip_option.dart';
import 'package:flutter_tipkit/src/model/tip_parameter.dart';
import 'package:flutter_tipkit/src/model/tip_rule.dart';

/// At most this many donations are kept per event, the newest ones.
const kMaxDonationsPerEvent = 1000;

/// A handle that keeps tips hidden until it is released. See `Tips.suppress`.
class TipSuppression {
  TipSuppression._(this._center);

  final TipsCenter _center;
  bool _isReleased = false;

  /// Whether [release] has been called.
  bool get isReleased => _isReleased;

  /// Lets tips show again, unless another suppression is still active.
  void release() {
    if (_isReleased) return;
    _isReleased = true;
    _center._releaseSuppression();
  }
}

/// The state of every tip, and the logic that decides which may show.
///
/// There is one instance, `Tips.center`. Most code uses the static methods
/// of `Tips` and the members of `Tip`, `TipParameter`, `TipEvent` and
/// `TipGroup` instead.
///
/// State changes apply in memory at once and are persisted in the background,
/// one write at a time, in order. Listeners are notified once per microtask,
/// however many changes it made, and never in the middle of a build.
class TipsCenter extends ChangeNotifier implements TipRuleContext {
  /// Creates an unconfigured center. Apps use the one in `Tips.center`.
  TipsCenter();

  TipDatastore _datastore = InMemoryTipDatastore();
  TipDisplayFrequency _displayFrequency = TipDisplayFrequency.immediate;
  void Function(TipLifecycleEvent event)? _onEvent;
  void Function(Object error, StackTrace stackTrace)? _onError;
  DateTime Function() _clock = DateTime.now;
  bool _isConfigured = false;

  final Map<String, TipRecord> _tips = {};
  final Map<String, Object?> _parameters = {};
  final Map<String, List<DateTime>> _events = {};
  TipGlobalRecord _global = const TipGlobalRecord();

  /// Every tip whose status was asked for, so time-based rules can be
  /// re-evaluated when their time comes.
  final Map<String, Tip> _knownTips = {};

  /// How many views display each tip right now, by tip id.
  final Map<String, int> _displayed = {};

  Object? _popoverOwner;
  int _suppressionCount = 0;
  bool? _testingShowAll;
  Set<String>? _testingTipIds;

  Future<void> _writes = Future.value();
  Timer? _timer;
  bool _isNotifyScheduled = false;
  bool _isRescheduleScheduled = false;
  bool _isDisposed = false;

  /// Whether `Tips.configure` has completed. Until then every tip is pending.
  bool get isConfigured => _isConfigured;

  /// The frequency new tips may appear at.
  TipDisplayFrequency get displayFrequency => _displayFrequency;

  @override
  DateTime get now => _clock();

  // Configuration.

  /// Loads the state from [datastore] and starts evaluating tips.
  ///
  /// Parameter values set and events donated before this call are kept, and
  /// written to [datastore].
  Future<void> configure({
    required TipDatastore datastore,
    required TipDisplayFrequency displayFrequency,
    void Function(TipLifecycleEvent event)? onEvent,
    void Function(Object error, StackTrace stackTrace)? onError,
    DateTime Function()? clock,
  }) async {
    if (_isConfigured) {
      throw StateError('Tips.configure was already called.');
    }
    _datastore = datastore;
    _displayFrequency = displayFrequency;
    _onEvent = onEvent;
    _onError = onError;
    if (clock != null) _clock = clock;

    final snapshot = await datastore.load();
    final earlyParameters = {..._parameters};
    final earlyEvents = {..._events};
    _tips
      ..clear()
      ..addAll(snapshot.tips);
    _parameters
      ..clear()
      ..addAll(snapshot.parameters)
      ..addAll(earlyParameters);
    _events
      ..clear()
      ..addAll({
        for (final MapEntry(:key, :value) in snapshot.events.entries)
          key: [...value],
      });
    for (final MapEntry(:key, :value) in earlyEvents.entries) {
      final donations = _trim([...?_events[key], ...value]);
      _events[key] = donations;
      _enqueue(() => datastore.writeEvent(key, donations));
    }
    for (final MapEntry(:key, :value) in earlyParameters.entries) {
      _enqueue(() => datastore.writeParameter(key, value));
    }
    _global = snapshot.global;
    _isConfigured = true;
    _changed();
  }

  /// Waits until every change so far has been written to the datastore.
  Future<void> flush() => _writes;

  /// Deletes the state of every tip, parameter and event, in memory and in
  /// the datastore.
  Future<void> resetDatastore() async {
    _tips.clear();
    _parameters.clear();
    _events.clear();
    _global = const TipGlobalRecord();
    _changed();
    _enqueue(_datastore.clear);
    await flush();
  }

  /// Makes every tip, or only [tips], available whatever its rules and
  /// stored state say, for testing and previews.
  void showAllTipsForTesting([List<Tip>? tips]) {
    _testingShowAll = true;
    _testingTipIds = tips?.map((tip) => tip.id).toSet();
    _changed();
  }

  /// Keeps every tip pending, for testing and screenshots.
  void hideAllTipsForTesting() {
    _testingShowAll = false;
    _testingTipIds = null;
    _changed();
  }

  /// Returns to an unconfigured center with no state, for tests.
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _datastore = InMemoryTipDatastore();
    _displayFrequency = TipDisplayFrequency.immediate;
    _onEvent = null;
    _onError = null;
    _clock = DateTime.now;
    _isConfigured = false;
    _tips.clear();
    _parameters.clear();
    _events.clear();
    _global = const TipGlobalRecord();
    _knownTips.clear();
    _displayed.clear();
    _popoverOwner = null;
    _suppressionCount = 0;
    _testingShowAll = null;
    _testingTipIds = null;
    _writes = Future.value();
    // A notification scheduled in another zone (such as a finished fakeAsync)
    // may never run.
    _isNotifyScheduled = false;
    _isRescheduleScheduled = false;
    _changed();
  }

  // Status.

  /// Whether [tip] may be displayed, judged by its rules and stored state.
  TipStatus status(Tip tip) {
    _register(tip);
    if (!_isConfigured) return TipStatus.pending;
    final testingShowAll = _testingShowAll;
    if (testingShowAll != null) {
      final ids = _testingTipIds;
      if (!testingShowAll) return TipStatus.pending;
      if (ids == null || ids.contains(tip.id)) return TipStatus.available;
    }
    final record = _tips[tip.id];
    final reason = record?.invalidationReason;
    if (reason != null) return TipInvalidated(reason);
    if (_isDisplayCountExceeded(tip) && !isDisplayed(tip)) {
      return const TipInvalidated(TipInvalidationReason.displayCountExceeded);
    }
    final rulesHold = tip.rules.every((rule) => rule.evaluate(this));
    return rulesHold ? TipStatus.available : TipStatus.pending;
  }

  /// Whether a view may display [tip] now: it is available, no suppression
  /// is active and the display frequency allows it.
  bool shouldDisplay(Tip tip) {
    if (!status(tip).isAvailable) return false;
    if (_suppressionCount > 0) return false;
    if (_testingShowAll ?? false) return true;
    return isDisplayed(tip) || _passesFrequency(tip);
  }

  /// Whether a view displays [tip] right now.
  bool isDisplayed(Tip tip) => (_displayed[tip.id] ?? 0) > 0;

  /// The tip [group] shows now, if any.
  Tip? currentTipOf(TipGroup group) {
    for (final tip in group.tips) {
      final status = this.status(tip);
      switch (group.priority) {
        case TipGroupPriority.ordered:
          if (status is TipInvalidated) continue;
          return status.isAvailable ? tip : null;
        case TipGroupPriority.firstAvailable:
          if (status.isAvailable) return tip;
      }
    }
    return null;
  }

  /// What is stored about [tip], if anything.
  TipRecord? recordOf(Tip tip) => _tips[tip.id];

  @override
  TipRecord? record(String tipId) => _tips[tipId];

  // Changes.

  /// Invalidates [tip] for [reason], so it is not displayed again.
  ///
  /// Does nothing if [tip] is already invalidated.
  void invalidate(Tip tip, TipInvalidationReason reason) {
    final record = _tips[tip.id] ?? const TipRecord();
    if (record.isInvalidated) return;
    final updated = record.copyWith(
      invalidatedAt: now,
      invalidationReason: reason,
    );
    _tips[tip.id] = updated;
    _enqueue(() => _datastore.writeTip(tip.id, updated));
    _onEvent?.call(TipInvalidatedEvent(tip, reason));
    _changed();
  }

  /// Reports that the user tapped [action] on [tip], and invalidates the tip
  /// if the action says so.
  void performAction(Tip tip, TipAction action) {
    _onEvent?.call(TipActionEvent(tip, action));
    if (action.invalidatesTip) {
      invalidate(tip, TipInvalidationReason.actionPerformed);
    }
  }

  /// Hides every tip until the returned handle is released, without
  /// invalidating anything.
  TipSuppression suppress() {
    _suppressionCount++;
    _changed();
    return TipSuppression._(this);
  }

  void _releaseSuppression() {
    _suppressionCount--;
    _changed();
  }

  @override
  T parameterValue<T>(TipParameter<T> parameter) {
    if (!_parameters.containsKey(parameter.id)) return parameter.defaultValue;
    return parameter.decodeStored(_parameters[parameter.id]);
  }

  /// Sets [parameter] to [value] and re-evaluates the tips.
  void setParameterValue<T>(TipParameter<T> parameter, T value) {
    final encoded = parameter.encodeValue(value);
    if (_parameters.containsKey(parameter.id) &&
        _deepEquals(_parameters[parameter.id], encoded)) {
      return;
    }
    _parameters[parameter.id] = encoded;
    if (_isConfigured) {
      _enqueue(() => _datastore.writeParameter(parameter.id, encoded));
    }
    _changed();
  }

  @override
  TipEventDonations donations(TipEvent event) {
    return TipEventDonations(_events[event.id] ?? const [], now: now);
  }

  /// Records a donation of [event] now and re-evaluates the tips.
  void donate(TipEvent event) {
    final donations = _trim([...?_events[event.id], now]);
    _events[event.id] = donations;
    if (_isConfigured) {
      _enqueue(() => _datastore.writeEvent(event.id, donations));
    }
    _changed();
  }

  // Display bookkeeping, for the views.

  /// Called by a view when it starts displaying [tip].
  void beginDisplay(Tip tip) {
    final count = _displayed[tip.id] ?? 0;
    _displayed[tip.id] = count + 1;
    if (count > 0 || !_isConfigured) return;

    final record = _tips[tip.id] ?? const TipRecord();
    final time = now;
    final updated = record.copyWith(
      displayCount: record.displayCount + 1,
      firstDisplayedAt: record.firstDisplayedAt ?? time,
      lastDisplayedAt: time,
    );
    _tips[tip.id] = updated;
    _enqueue(() => _datastore.writeTip(tip.id, updated));
    if (record.displayCount == 0 && !_ignoresFrequency(tip)) {
      _global = TipGlobalRecord(lastNewTipId: tip.id, lastNewTipShownAt: time);
      final global = _global;
      _enqueue(() => _datastore.writeGlobal(global));
    }
    _onEvent?.call(TipShownEvent(tip, displayCount: updated.displayCount));
    _changed();
  }

  /// Called by a view when it stops displaying [tip].
  void endDisplay(Tip tip) {
    final count = _displayed[tip.id] ?? 0;
    if (count <= 1) {
      _displayed.remove(tip.id);
    } else {
      _displayed[tip.id] = count - 1;
      return;
    }
    if (_isDisplayCountExceeded(tip)) {
      invalidate(tip, TipInvalidationReason.displayCountExceeded);
    } else {
      _changed();
    }
  }

  /// Lets [owner] display a popover tip if no other popover is displayed.
  ///
  /// Only one popover shows at a time; the others wait until it is released.
  bool claimPopover(Object owner) {
    if (_popoverOwner != null && !identical(_popoverOwner, owner)) {
      return false;
    }
    _popoverOwner = owner;
    return true;
  }

  /// Lets another popover show, if [owner] holds the claim.
  void releasePopover(Object owner) {
    if (!identical(_popoverOwner, owner)) return;
    _popoverOwner = null;
    _changed();
  }

  // Internals.

  void _register(Tip tip) {
    if (_knownTips.containsKey(tip.id)) return;
    _knownTips[tip.id] = tip;
    _rescheduleSoon();
  }

  bool _ignoresFrequency(Tip tip) =>
      tip.options.any((option) => option is IgnoresDisplayFrequencyOption);

  int? _maxDisplayCount(Tip tip) {
    for (final option in tip.options) {
      if (option is MaxDisplayCountOption) return option.count;
    }
    return null;
  }

  bool _isDisplayCountExceeded(Tip tip) {
    final max = _maxDisplayCount(tip);
    if (max == null) return false;
    return (_tips[tip.id]?.displayCount ?? 0) >= max;
  }

  /// When the display frequency lets the next new tip appear.
  DateTime? get _frequencyOpensAt {
    final shownAt = _global.lastNewTipShownAt;
    if (shownAt == null) return null;
    return shownAt.add(_displayFrequency.interval);
  }

  bool _passesFrequency(Tip tip) {
    if (_displayFrequency == TipDisplayFrequency.immediate) return true;
    if (_ignoresFrequency(tip)) return true;
    // Only tips that have never been displayed are held back.
    if ((_tips[tip.id]?.displayCount ?? 0) > 0) return true;
    final opensAt = _frequencyOpensAt;
    return opensAt == null || !opensAt.isAfter(now);
  }

  List<DateTime> _trim(List<DateTime> donations) {
    if (donations.length <= kMaxDonationsPerEvent) return donations;
    return donations.sublist(donations.length - kMaxDonationsPerEvent);
  }

  void _enqueue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError(_reportError);
  }

  void _reportError(Object error, StackTrace stackTrace) {
    final onError = _onError;
    if (onError != null) {
      onError(error, stackTrace);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'flutter_tipkit',
        context: ErrorDescription('while writing tip state'),
      ),
    );
  }

  /// Notifies listeners in a microtask, and re-arms the timer for time-based
  /// rules.
  void _changed() {
    _rescheduleSoon();
    if (_isNotifyScheduled) return;
    _isNotifyScheduled = true;
    scheduleMicrotask(() {
      _isNotifyScheduled = false;
      if (!_isDisposed) notifyListeners();
    });
  }

  void _rescheduleSoon() {
    if (_isRescheduleScheduled) return;
    _isRescheduleScheduled = true;
    scheduleMicrotask(() {
      _isRescheduleScheduled = false;
      if (!_isDisposed) _reschedule();
    });
  }

  /// Arms a timer for the earliest time a tip's status or the display
  /// frequency can change by itself.
  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!_isConfigured) return;
    final time = now;
    DateTime? next;
    void consider(DateTime? candidate) {
      if (candidate == null || !candidate.isAfter(time)) return;
      if (next == null || candidate.isBefore(next!)) next = candidate;
    }

    for (final tip in _knownTips.values) {
      if (_tips[tip.id]?.isInvalidated ?? false) continue;
      consider(earliestNextChange(tip.rules, this));
    }
    consider(_frequencyOpensAt);
    final at = next;
    if (at == null) return;
    _timer = Timer(at.difference(time), () {
      _timer = null;
      _changed();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}
