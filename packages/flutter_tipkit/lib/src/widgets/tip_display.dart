import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/model/tip_group.dart';

/// Provides the content of a tip where it is shown, for example from
/// context-based localization.
typedef TipContentResolver = TipContent Function(BuildContext context, Tip tip);

/// Called with the tip and the action the user tapped on it.
typedef TipActionCallback = void Function(Tip tip, TipAction action);

/// Called with the tip the user closed.
typedef TipCloseCallback = void Function(Tip tip);

/// The tip a view asking for [tip] and [group] should display now, if any.
///
/// - With only [tip]: that tip, when it may be displayed.
/// - With only [group]: the group's current tip, when it may be displayed.
/// - With both: [tip], when it is the group's current tip and may be
///   displayed. Lets the tips of one group show at different places.
Tip? resolveDisplayableTip({Tip? tip, TipGroup? group}) {
  var candidate = tip;
  if (group != null) {
    final current = Tips.center.currentTipOf(group);
    if (current == null || (tip != null && current != tip)) return null;
    candidate = current;
  }
  if (candidate == null) return null;
  return Tips.center.shouldDisplay(candidate) ? candidate : null;
}

/// Keeps a tip view in step with `Tips.center`: calls [syncTipDisplay]
/// after the first frame and whenever the tip state or the view's visibility
/// changes, never during a build.
///
/// A view counts as visible while tickers are enabled for it (so not in an
/// inactive tab that is kept alive) and its route, if any, is the current
/// one (so not under another screen, dialog or sheet). An invisible view
/// shows nothing, does not count displays, and does not hold the popover
/// claim, so it can never block the visible screen.
mixin TipDisplayStateMixin<T extends StatefulWidget> on State<T> {
  bool _isSyncScheduled = false;
  bool _isHostVisible = true;

  /// Whether the view is on the visible screen.
  bool get isHostVisible => _isHostVisible;

  /// Starts or stops displaying a tip to match the current state.
  void syncTipDisplay();

  /// Like [resolveDisplayableTip], but null while the view is not visible.
  Tip? resolveTipForHost({Tip? tip, TipGroup? group}) {
    if (!_isHostVisible) return null;
    return resolveDisplayableTip(tip: tip, group: group);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (isVisible == _isHostVisible) return;
    _isHostVisible = isVisible;
    scheduleTipSync();
  }

  /// Calls [syncTipDisplay] now, or after the current frame while building.
  void scheduleTipSync() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final isBuilding =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!isBuilding) {
      if (mounted) syncTipDisplay();
      return;
    }
    if (_isSyncScheduled) return;
    _isSyncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isSyncScheduled = false;
      if (mounted) syncTipDisplay();
    });
  }

  @override
  void initState() {
    super.initState();
    Tips.center.addListener(scheduleTipSync);
    scheduleTipSync();
  }

  @override
  void dispose() {
    Tips.center.removeListener(scheduleTipSync);
    super.dispose();
  }
}
