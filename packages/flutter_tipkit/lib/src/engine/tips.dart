import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/datastore/in_memory_tip_datastore.dart';
import 'package:flutter_tipkit/src/datastore/tip_datastore.dart';
import 'package:flutter_tipkit/src/engine/tip_display_frequency.dart';
import 'package:flutter_tipkit/src/engine/tip_lifecycle_event.dart';
import 'package:flutter_tipkit/src/engine/tips_center.dart';
import 'package:flutter_tipkit/src/model/tip.dart';

/// The entry point of the tip system.
///
/// Call [configure] once at startup. Until then every tip is pending.
abstract final class Tips {
  static final TipsCenter _center = TipsCenter();
  static final Map<String, _TipStatusListenable> _statusListenables = {};

  /// The state of every tip. Listen to it to learn about any change.
  static TipsCenter get center => _center;

  /// Loads the stored tip state and lets tips appear.
  ///
  /// - [datastore] persists the state. The default keeps it in memory only,
  ///   so tips start over on every launch.
  /// - [displayFrequency] limits how often new tips appear.
  /// - [onEvent] reports each tip shown, action tapped and tip invalidated,
  ///   for example to log them to analytics.
  /// - [onError] receives errors from the datastore. By default they go to
  ///   `FlutterError.reportError`.
  /// - [clock] replaces `DateTime.now`, for tests.
  ///
  /// Throws a [StateError] when called twice.
  static Future<void> configure({
    TipDatastore? datastore,
    TipDisplayFrequency displayFrequency = TipDisplayFrequency.immediate,
    void Function(TipLifecycleEvent event)? onEvent,
    void Function(Object error, StackTrace stackTrace)? onError,
    DateTime Function()? clock,
  }) {
    return _center.configure(
      datastore: datastore ?? InMemoryTipDatastore(),
      displayFrequency: displayFrequency,
      onEvent: onEvent,
      onError: onError,
      clock: clock,
    );
  }

  /// Whether [configure] has completed.
  static bool get isConfigured => _center.isConfigured;

  /// The current status of [tip].
  static TipStatus status(Tip tip) => _center.status(tip);

  /// The status of [tip], updated as it changes.
  static ValueListenable<TipStatus> statusListenable(Tip tip) {
    return _statusListenables.putIfAbsent(
      tip.id,
      () => _TipStatusListenable(tip),
    );
  }

  /// Hides every tip until the returned handle is released, without
  /// invalidating anything: for example while a full-screen dialog is open.
  static TipSuppression suppress() => _center.suppress();

  /// Waits until every change so far has been written to the datastore.
  static Future<void> flush() => _center.flush();

  /// Deletes the state of every tip, parameter and event.
  static Future<void> resetDatastore() => _center.resetDatastore();

  /// Makes every tip, or only [tips], available, for testing and previews.
  static void showAllTipsForTesting([List<Tip>? tips]) {
    _center.showAllTipsForTesting(tips);
  }

  /// Keeps every tip hidden, for testing and screenshots.
  static void hideAllTipsForTesting() => _center.hideAllTipsForTesting();

  /// Returns to an unconfigured state with nothing stored, for tests.
  @visibleForTesting
  static void resetForTesting() {
    _center.resetForTesting();
  }
}

/// Convenience members of a [Tip], backed by [Tips].
extension TipMembers on Tip {
  /// The current status of the tip.
  TipStatus get status => Tips.center.status(this);

  /// Whether a view may display the tip now.
  bool get shouldDisplay => Tips.center.shouldDisplay(this);

  /// Invalidates the tip for [reason], so it is not displayed again.
  void invalidate(TipInvalidationReason reason) {
    Tips.center.invalidate(this, reason);
  }
}

class _TipStatusListenable extends ChangeNotifier
    implements ValueListenable<TipStatus> {
  _TipStatusListenable(this.tip);

  final Tip tip;
  TipStatus? _value;

  @override
  TipStatus get value => _value ?? Tips.center.status(tip);

  void _update() {
    final next = Tips.center.status(tip);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      _value = Tips.center.status(tip);
      Tips.center.addListener(_update);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      Tips.center.removeListener(_update);
      _value = null;
    }
  }
}
