import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

import '../helpers.dart';

void main() {
  late TestClock clock;

  Future<void> configure({
    TipDatastore? datastore,
    TipDisplayFrequency frequency = TipDisplayFrequency.immediate,
    void Function(TipLifecycleEvent)? onEvent,
  }) {
    return Tips.configure(
      datastore: datastore,
      displayFrequency: frequency,
      onEvent: onEvent,
      clock: clock.call,
    );
  }

  setUp(() {
    Tips.resetForTesting();
    clock = TestClock();
  });

  tearDown(Tips.resetForTesting);

  group('status', () {
    test('is pending until configured', () async {
      const tip = TestTip('a');
      expect(tip.status, TipStatus.pending);
      await configure();
      expect(tip.status, TipStatus.available);
    });

    test('is invalidated with the reason, and invalidating twice keeps the '
        'first reason', () async {
      await configure();
      final tip = const TestTip('a')
        ..invalidate(TipInvalidationReason.tipClosed)
        ..invalidate(TipInvalidationReason.actionPerformed);
      expect(tip.status, const TipInvalidated(TipInvalidationReason.tipClosed));
    });

    test('compares tips by id', () async {
      await configure();
      const TestTip('a').invalidate(TipInvalidationReason.tipClosed);
      expect(const TestTip('a', title: 'Other').status, isA<TipInvalidated>());
    });
  });

  group('rules', () {
    test(
      'parameter rule follows the value, which survives a relaunch',
      () async {
        final datastore = InMemoryTipDatastore();
        const loggedIn = TipParameter<bool>('loggedIn', false);
        final tip = TestTip(
          'a',
          rules: [TipRule.parameter(loggedIn, (value) => value)],
        );
        await configure(datastore: datastore);
        expect(tip.status, TipStatus.pending);
        loggedIn.value = true;
        expect(tip.status, TipStatus.available);
        await Tips.flush();

        Tips.resetForTesting();
        await configure(datastore: datastore);
        expect(loggedIn.value, isTrue);
        expect(tip.status, TipStatus.available);
      },
    );

    test('parameter set before configure is kept and stored', () async {
      final datastore = InMemoryTipDatastore();
      const count = TipParameter<int>('count', 0);
      count.value = 3;
      await configure(datastore: datastore);
      await Tips.flush();
      expect(count.value, 3);
      expect(datastore.snapshot.parameters['count'], 3);
    });

    test('parameter with encode and decode', () async {
      final datastore = InMemoryTipDatastore();
      final since = TipParameter<DateTime?>(
        'since',
        null,
        encode: (value) => value?.millisecondsSinceEpoch,
        decode: (stored) => stored is int
            ? DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true)
            : null,
      );
      await configure(datastore: datastore);
      since.value = DateTime.utc(2025);
      await Tips.flush();
      expect(
        datastore.snapshot.parameters['since'],
        DateTime.utc(2025).millisecondsSinceEpoch,
      );
      expect(since.value, DateTime.utc(2025));
    });

    test('event rule counts donations in a window', () async {
      const opened = TipEvent('opened');
      final tip = TestTip(
        'a',
        rules: [
          TipRule.event(
            opened,
            (donations) => donations.within(const Duration(days: 1)) >= 2,
          ),
        ],
      );
      await configure();
      opened.donate();
      clock.advance(const Duration(days: 2));
      opened.donate();
      expect(opened.donations.count, 2);
      expect(tip.status, TipStatus.pending);
      opened.donate();
      expect(tip.status, TipStatus.available);
    });

    test('donations before configure are added to the stored ones', () async {
      const opened = TipEvent('opened');
      final datastore = InMemoryTipDatastore(
        TipStoreSnapshot(
          events: {
            'opened': [DateTime.utc(2025)],
          },
        ),
      );
      opened.donate();
      await configure(datastore: datastore);
      await Tips.flush();
      expect(opened.donations.count, 2);
      expect(datastore.snapshot.events['opened'], hasLength(2));
    });

    test('tipInvalidated waits for minAge and then fires on its own', () {
      fakeAsync((async) {
        clock = TestClock(DateTime.utc(2026));
        // fakeAsync's clock drives the rule, so the timer and the clock agree.
        final start = clock.now;
        DateTime now() => start.add(async.elapsed);
        const first = TestTip('first');
        final second = TestTip(
          'second',
          rules: [
            TipRule.tipInvalidated(first, minAge: const Duration(hours: 12)),
          ],
        );
        unawaited(Tips.configure(clock: now));
        async.flushMicrotasks();

        expect(second.status, TipStatus.pending);
        first.invalidate(TipInvalidationReason.actionPerformed);
        var notified = 0;
        Tips.center.addListener(() => notified++);
        async.flushMicrotasks();
        expect(second.status, TipStatus.pending);
        notified = 0;

        async.elapse(const Duration(hours: 12));
        expect(second.status, TipStatus.available);
        expect(notified, greaterThan(0));
        Tips.resetForTesting();
      });
    });

    test('tipInvalidated can require reasons', () async {
      await configure();
      const first = TestTip('first');
      final second = TestTip(
        'second',
        rules: [
          TipRule.tipInvalidated(
            first,
            reasons: {TipInvalidationReason.actionPerformed},
          ),
        ],
      );
      first.invalidate(TipInvalidationReason.tipClosed);
      expect(second.status, TipStatus.pending);
    });

    test('allOf, anyOf and not combine rules', () async {
      await configure();
      const a = TipParameter<bool>('a', false);
      const b = TipParameter<bool>('b', false);
      final isA = TipRule.parameter(a, (value) => value);
      final isB = TipRule.parameter(b, (value) => value);
      final all = TestTip(
        'all',
        rules: [
          TipRule.allOf([isA, isB]),
        ],
      );
      final any = TestTip(
        'any',
        rules: [
          TipRule.anyOf([isA, isB]),
        ],
      );
      final notA = TestTip('notA', rules: [TipRule.not(isA)]);

      expect(all.status, TipStatus.pending);
      expect(any.status, TipStatus.pending);
      expect(notA.status, TipStatus.available);
      a.value = true;
      expect(all.status, TipStatus.pending);
      expect(any.status, TipStatus.available);
      expect(notA.status, TipStatus.pending);
      b.value = true;
      expect(all.status, TipStatus.available);
    });
  });

  group('groups', () {
    const a = TestTip('a');
    const b = TestTip('b');
    const c = TestTip('c');

    test('ordered shows the tips one after another', () async {
      await configure();
      const group = TipGroup.ordered([a, b, c]);
      expect(group.currentTip, a);
      a.invalidate(TipInvalidationReason.actionPerformed);
      expect(group.currentTip, b);
      b.invalidate(TipInvalidationReason.tipClosed);
      expect(group.currentTip, c);
      c.invalidate(TipInvalidationReason.actionPerformed);
      expect(group.currentTip, isNull);
      expect(group.isCompleted, isTrue);
    });

    test('ordered waits while the next tip is pending', () async {
      await configure();
      const ready = TipParameter<bool>('ready', false);
      final waiting = TestTip(
        'waiting',
        rules: [TipRule.parameter(ready, (value) => value)],
      );
      final group = TipGroup.ordered([waiting, b]);
      expect(group.currentTip, isNull);
      ready.value = true;
      expect(group.currentTip, waiting);
    });

    test('firstAvailable skips pending tips', () async {
      await configure();
      const never = TipParameter<bool>('never', false);
      final pending = TestTip(
        'pending',
        rules: [TipRule.parameter(never, (value) => value)],
      );
      final group = TipGroup.firstAvailable([pending, b]);
      expect(group.currentTip, b);
    });

    test('the order can be chosen at runtime and resumes from the stored '
        'state', () async {
      final datastore = InMemoryTipDatastore();
      await configure(datastore: datastore);
      const TipGroup.ordered([
        c,
        a,
        b,
      ]).currentTip!.invalidate(TipInvalidationReason.actionPerformed);
      await Tips.flush();

      Tips.resetForTesting();
      await configure(datastore: datastore);
      expect(const TipGroup.ordered([c, a, b]).currentTip, a);
      expect(const TipGroup.ordered([a, b, c]).currentTip, a);
    });
  });

  group('display', () {
    test('beginDisplay counts displays and reports them', () async {
      final events = <TipLifecycleEvent>[];
      await configure(onEvent: events.add);
      const tip = TestTip('a');
      Tips.center
        ..beginDisplay(tip)
        ..beginDisplay(tip)
        ..endDisplay(tip)
        ..endDisplay(tip)
        ..beginDisplay(tip);
      expect(Tips.center.recordOf(tip)?.displayCount, 2);
      expect(events.whereType<TipShownEvent>(), hasLength(2));
    });

    test('maxDisplayCount invalidates once the last display ends', () async {
      await configure();
      const tip = TestTip('a', options: [TipOption.maxDisplayCount(2)]);
      Tips.center
        ..beginDisplay(tip)
        ..endDisplay(tip)
        ..beginDisplay(tip);
      expect(tip.status, TipStatus.available);
      Tips.center.endDisplay(tip);
      expect(
        tip.status,
        const TipInvalidated(TipInvalidationReason.displayCountExceeded),
      );
      expect(
        Tips.center.recordOf(tip)?.invalidationReason,
        TipInvalidationReason.displayCountExceeded,
      );
    });

    test('display frequency holds back new tips only', () async {
      await configure(frequency: TipDisplayFrequency.daily);
      const first = TestTip('first');
      const second = TestTip('second');
      const urgent = TestTip(
        'urgent',
        options: [TipOption.ignoresDisplayFrequency()],
      );
      expect(second.shouldDisplay, isTrue);
      Tips.center
        ..beginDisplay(first)
        ..endDisplay(first);

      expect(second.status, TipStatus.available);
      expect(second.shouldDisplay, isFalse);
      expect(first.shouldDisplay, isTrue, reason: 'shown before');
      expect(urgent.shouldDisplay, isTrue);

      clock.advance(const Duration(days: 1));
      expect(second.shouldDisplay, isTrue);
    });

    test('suppress hides without invalidating', () async {
      await configure();
      const tip = TestTip('a');
      final first = Tips.suppress();
      final second = Tips.suppress();
      expect(tip.shouldDisplay, isFalse);
      expect(tip.status, TipStatus.available);
      first
        ..release()
        ..release();
      expect(tip.shouldDisplay, isFalse);
      second.release();
      expect(tip.shouldDisplay, isTrue);
    });

    test('one popover owner at a time', () async {
      await configure();
      final first = Object();
      final second = Object();
      expect(Tips.center.claimPopover(first), isTrue);
      expect(Tips.center.claimPopover(first), isTrue);
      expect(Tips.center.claimPopover(second), isFalse);
      Tips.center.releasePopover(second);
      expect(Tips.center.claimPopover(second), isFalse);
      Tips.center.releasePopover(first);
      expect(Tips.center.claimPopover(second), isTrue);
    });
  });

  group('actions', () {
    test('an action reports itself and invalidates by default', () async {
      final events = <TipLifecycleEvent>[];
      await configure(onEvent: events.add);
      const next = TipAction(id: 'next', label: 'Next');
      const later = TipAction(
        id: 'later',
        label: 'Later',
        invalidatesTip: false,
      );
      const tip = TestTip('a', actions: [next, later]);

      Tips.center.performAction(tip, later);
      expect(tip.status, TipStatus.available);
      Tips.center.performAction(tip, next);
      expect(
        tip.status,
        const TipInvalidated(TipInvalidationReason.actionPerformed),
      );
      expect(events, [
        isA<TipActionEvent>().having((e) => e.action, 'action', later),
        isA<TipActionEvent>().having((e) => e.action, 'action', next),
        isA<TipInvalidatedEvent>().having(
          (e) => e.reason,
          'reason',
          TipInvalidationReason.actionPerformed,
        ),
      ]);
    });
  });

  group('persistence', () {
    test('writes are applied in order, one at a time', () async {
      final datastore = RecordingDatastore();
      await configure(datastore: datastore);
      const tip = TestTip('a');
      const count = TipParameter<int>('count', 0);
      Tips.center.beginDisplay(tip);
      count.value = 1;
      tip.invalidate(TipInvalidationReason.tipClosed);
      await Tips.flush();
      expect(datastore.writes, [
        'tip:a',
        'global:a',
        'parameter:count=1',
        'tip:a',
      ]);
      expect(
        datastore.snapshot.tips['a']?.invalidationReason,
        TipInvalidationReason.tipClosed,
      );
    });

    test('state is in memory before it is written', () async {
      final datastore = RecordingDatastore();
      await configure(datastore: datastore);
      final tip = const TestTip('a')
        ..invalidate(TipInvalidationReason.tipClosed);
      expect(tip.status, isA<TipInvalidated>());
      expect(datastore.writes, isEmpty);
      await Tips.flush();
      expect(datastore.writes, ['tip:a']);
    });

    test('a failing write is reported and later writes still run', () async {
      final errors = <Object>[];
      final datastore = _FailingOnceDatastore();
      await Tips.configure(
        datastore: datastore,
        onError: (e, _) => errors.add(e),
      );
      const TestTip('a').invalidate(TipInvalidationReason.tipClosed);
      const TestTip('b').invalidate(TipInvalidationReason.tipClosed);
      await Tips.flush();
      expect(errors, hasLength(1));
      expect(datastore.snapshot.tips.keys, ['b']);
    });

    test('resetDatastore clears memory and storage', () async {
      final datastore = InMemoryTipDatastore();
      await configure(datastore: datastore);
      final tip = const TestTip('a')
        ..invalidate(TipInvalidationReason.tipClosed);
      await Tips.resetDatastore();
      expect(tip.status, TipStatus.available);
      expect(datastore.snapshot.tips, isEmpty);
    });

    test('configure twice throws', () async {
      await configure();
      expect(configure, throwsStateError);
    });

    test('TipRecord round-trips through JSON', () {
      final record = TipRecord(
        displayCount: 3,
        firstDisplayedAt: DateTime.utc(2025),
        lastDisplayedAt: DateTime.utc(2026),
        invalidatedAt: DateTime.utc(2026, 2),
        invalidationReason: TipInvalidationReason.displayCountExceeded,
      );
      expect(TipRecord.fromJson(record.toJson()), record);
    });
  });

  group('testing helpers and listeners', () {
    test('showAllTipsForTesting and hideAllTipsForTesting', () async {
      await configure();
      final closed = const TestTip('closed')
        ..invalidate(TipInvalidationReason.tipClosed);
      Tips.showAllTipsForTesting();
      expect(closed.status, TipStatus.available);
      Tips.hideAllTipsForTesting();
      expect(const TestTip('other').status, TipStatus.pending);
    });

    test('statusListenable notifies when the status changes', () async {
      await configure();
      const tip = TestTip('a');
      final listenable = Tips.statusListenable(tip);
      final seen = <TipStatus>[];
      void listener() => seen.add(listenable.value);
      listenable.addListener(listener);
      tip.invalidate(TipInvalidationReason.tipClosed);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [const TipInvalidated(TipInvalidationReason.tipClosed)]);
      listenable.removeListener(listener);
    });

    test('listeners are notified once per microtask', () async {
      await configure();
      var notified = 0;
      void listener() => notified++;
      Tips.center.addListener(listener);
      const TestTip('a').invalidate(TipInvalidationReason.tipClosed);
      const TestTip('b').invalidate(TipInvalidationReason.tipClosed);
      expect(notified, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);
      Tips.center.removeListener(listener);
    });
  });
}

class _FailingOnceDatastore extends InMemoryTipDatastore {
  bool _failed = false;

  @override
  Future<void> writeTip(String tipId, TipRecord? record) async {
    if (!_failed) {
      _failed = true;
      throw StateError('disk full');
    }
    await super.writeTip(tipId, record);
  }
}
