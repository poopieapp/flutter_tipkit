import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

import '../helpers.dart';
import 'harness.dart';

const _targetKey = Key('target');
const _targetSize = 40.0;

/// A [PopoverTipWidget] pointing at a square at [targetCentre].
Widget _popover({
  required Offset targetCentre,
  Tip tip = const TestTip('a', title: 'Hello', message: 'A popover tip'),
  TipArrowEdge? arrowEdge,
  TipArrowAlignment arrowAlignment = TipArrowAlignment.center,
  TipBarrierBehavior barrierBehavior = TipBarrierBehavior.close,
}) {
  return Stack(
    children: [
      Positioned(
        left: targetCentre.dx - _targetSize / 2,
        top: targetCentre.dy - _targetSize / 2,
        child: PopoverTipWidget(
          tip: tip,
          arrowEdge: arrowEdge,
          arrowAlignment: arrowAlignment,
          barrierBehavior: barrierBehavior,
          child: const SizedBox.square(key: _targetKey, dimension: _targetSize),
        ),
      ),
    ],
  );
}

Rect _cardRect(WidgetTester tester) => tester.getRect(find.byType(TipCard));

double? _arrowPosition(WidgetTester tester) {
  final bubble = tester.widget<TipBubble>(find.byType(TipBubble));
  return bubble.arrowPosition?.value;
}

void main() {
  setUpTipTests();

  testWidgets('opens below its target with the arrow on top', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        _popover(
          targetCentre: const Offset(200, 200),
          arrowEdge: TipArrowEdge.top,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(_targetKey));
    final card = _cardRect(tester);
    expect(find.text('Hello'), findsOneWidget);
    expect(card.top, moreOrLessEquals(target.bottom + 4));
    expect(card.center.dx, moreOrLessEquals(target.center.dx));
    expect(_arrowPosition(tester), moreOrLessEquals(card.width / 2));
  });

  testWidgets('opens above its target with the arrow at the bottom', (
    tester,
  ) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        _popover(
          targetCentre: const Offset(200, 600),
          arrowEdge: TipArrowEdge.bottom,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(_targetKey));
    expect(_cardRect(tester).bottom, moreOrLessEquals(target.top - 4));
  });

  testWidgets('without an edge, opens where there is more room', (
    tester,
  ) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(_popover(targetCentre: const Offset(200, 700))),
    );
    await tester.pumpAndSettle();
    final target = tester.getRect(find.byKey(_targetKey));
    expect(_cardRect(tester).bottom, lessThanOrEqualTo(target.top));
  });

  testWidgets('stays on screen near the edge, with the arrow on the target', (
    tester,
  ) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        _popover(
          targetCentre: const Offset(350, 200),
          arrowEdge: TipArrowEdge.top,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(_targetKey));
    final card = _cardRect(tester);
    expect(card.right, lessThanOrEqualTo(kScreenSize.width - 8));
    expect(card.left, greaterThanOrEqualTo(8));
    final arrowCentre = card.left + _arrowPosition(tester)!;
    expect(arrowCentre, moreOrLessEquals(target.center.dx));
  });

  testWidgets('respects the maximum width', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        _popover(targetCentre: const Offset(200, 200)),
        theme: const TipThemeData(popoverMaxWidth: 250),
      ),
    );
    await tester.pumpAndSettle();
    expect(_cardRect(tester).width, lessThanOrEqualTo(250));
  });

  testWidgets('a start edge opens after the target, mirrored in RTL', (
    tester,
  ) async {
    useScreenSize(tester);
    await Tips.configure();
    Widget build(TextDirection direction) => harness(
      _popover(
        targetCentre: const Offset(60, 300),
        arrowEdge: TipArrowEdge.start,
      ),
      direction: direction,
    );

    await tester.pumpWidget(build(TextDirection.ltr));
    await tester.pumpAndSettle();
    final target = tester.getRect(find.byKey(_targetKey));
    expect(_cardRect(tester).left, moreOrLessEquals(target.right + 4));
    expect(
      _cardRect(tester).center.dy,
      moreOrLessEquals(target.center.dy, epsilon: 1),
    );

    await tester.pumpWidget(const SizedBox());
    Tips.resetForTesting();
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        _popover(
          targetCentre: const Offset(340, 300),
          arrowEdge: TipArrowEdge.start,
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    final rtlTarget = tester.getRect(find.byKey(_targetKey));
    expect(_cardRect(tester).right, moreOrLessEquals(rtlTarget.left - 4));
  });

  group('barrier', () {
    testWidgets('close invalidates the tip', (tester) async {
      useScreenSize(tester);
      await Tips.configure();
      const tip = TestTip('a', title: 'Hello');
      await tester.pumpWidget(
        harness(_popover(targetCentre: const Offset(200, 200), tip: tip)),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 780));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect(tip.status, const TipInvalidated(TipInvalidationReason.tipClosed));
    });

    testWidgets('dismiss hides the tip without invalidating it', (
      tester,
    ) async {
      useScreenSize(tester);
      await Tips.configure();
      const tip = TestTip('a', title: 'Hello');
      await tester.pumpWidget(
        harness(
          _popover(
            targetCentre: const Offset(200, 200),
            tip: tip,
            barrierBehavior: TipBarrierBehavior.dismiss,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 780));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect(tip.status, TipStatus.available);
    });

    testWidgets('block keeps the tip and absorbs the tap', (tester) async {
      useScreenSize(tester);
      await Tips.configure();
      var behindTapped = false;
      await tester.pumpWidget(
        harness(
          Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => behindTapped = true,
                  child: const SizedBox.expand(),
                ),
              ),
              _popover(
                targetCentre: const Offset(200, 200),
                barrierBehavior: TipBarrierBehavior.block,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 780));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(behindTapped, isFalse);
    });

    testWidgets('a tap on the tip itself does not close it', (tester) async {
      useScreenSize(tester);
      await Tips.configure();
      await tester.pumpWidget(
        harness(_popover(targetCentre: const Offset(200, 200))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A popover tip'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  testWidgets('only one popover shows at a time', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        Stack(
          children: [
            _popover(
              targetCentre: const Offset(100, 100),
              tip: const TestTip('first', title: 'First'),
            ),
            _popover(
              targetCentre: const Offset(300, 500),
              tip: const TestTip('second', title: 'Second'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    await tester.tap(find.byType(TipCloseButton));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('an action closes the popover', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    const tip = TestTip(
      'a',
      title: 'Hello',
      actions: [TipAction(id: 'ok', label: 'OK')],
    );
    await tester.pumpWidget(
      harness(_popover(targetCentre: const Offset(200, 200), tip: tip)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
    expect(
      tip.status,
      const TipInvalidated(TipInvalidationReason.actionPerformed),
    );
  });

  testWidgets('the target is neither hidden nor copied', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(
      harness(_popover(targetCentre: const Offset(200, 200))),
    );
    await tester.pumpAndSettle();
    final opacity = find.ancestor(
      of: find.byKey(_targetKey),
      matching: find.byType(Opacity),
    );
    expect(opacity, findsNothing);
  });
}
