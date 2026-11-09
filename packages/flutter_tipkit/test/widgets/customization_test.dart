import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

import '../helpers.dart';
import 'harness.dart';

void main() {
  setUpTipTests();

  group('TipBubbleBorder', () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);

    test('reserves room for the arrow on its side', () {
      const border = TipBubbleBorder(
        arrowSide: TipSide.left,
        arrowShape: TipArrowShape.triangle(size: Size(16, 8)),
      );
      expect(border.dimensions, const EdgeInsets.only(left: 8));
      expect(const TipBubbleBorder().dimensions, EdgeInsets.zero);
    });

    test('the arrow points out of its side, from the requested position', () {
      const border = TipBubbleBorder(arrowSide: TipSide.top, arrowPosition: 60);
      final path = border.getOuterPath(rect);
      expect(path.contains(const Offset(60, 1)), isTrue, reason: 'arrow');
      expect(path.contains(const Offset(100, 1)), isFalse, reason: 'beside');
      expect(path.contains(const Offset(100, 50)), isTrue, reason: 'body');
    });

    test('the arrow keeps clear of rounded corners', () {
      const border = TipBubbleBorder(
        arrowSide: TipSide.bottom,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        arrowPosition: 0,
      );
      expect(border.arrowClearance(TextDirection.ltr), 22);
      final path = border.getOuterPath(rect);
      expect(path.contains(const Offset(22, 99)), isTrue);
      expect(path.contains(const Offset(2, 99)), isFalse);
    });

    test('a rounded arrow is narrower near its tip than a triangle', () {
      // Both use the default 20 x 10 size.
      final triangle = const TipArrowShape.triangle().pathPointingUp();
      final rounded = const TipArrowShape.rounded(
        tipRadius: 4,
      ).pathPointingUp();
      const nearTip = Offset(0, -9.5);
      expect(triangle.contains(nearTip), isTrue);
      expect(rounded.contains(nearTip), isFalse);
    });

    test('scales and interpolates', () {
      const a = TipBubbleBorder(
        side: BorderSide(width: 2),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        arrowSide: TipSide.top,
      );
      final scaled = a.scale(2) as TipBubbleBorder;
      expect(scaled.side.width, 4);
      expect(scaled.arrowShape.size, const Size(40, 20));

      const b = TipBubbleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        arrowSide: TipSide.top,
      );
      final halfway = ShapeBorder.lerp(a, b, 0.5)! as TipBubbleBorder;
      expect(halfway.borderRadius, const BorderRadius.all(Radius.circular(15)));
    });
  });

  testWidgets('a gradient fill and a custom arrow paint without errors', (
    tester,
  ) async {
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        const TipWidget(
          tip: TestTip('a', title: 'Hello'),
          arrowEdge: TipArrowEdge.top,
        ),
        theme: const TipThemeData(
          gradient: LinearGradient(
            colors: [Color(0xFFFFEEDD), Color(0xFFDDEEFF)],
          ),
          inlineShadows: [BoxShadow(blurRadius: 4, spreadRadius: 2)],
          arrowShape: TipArrowShape.rounded(size: Size(24, 12)),
          borderSide: BorderSide(color: Color(0xFFFF0000), width: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('card builder', () {
    testWidgets('the theme builder replaces the card and keeps the logic', (
      tester,
    ) async {
      await Tips.configure();
      const tip = TestTip(
        'a',
        title: 'Hello',
        actions: [TipAction(id: 'ok', label: 'OK')],
      );
      await tester.pumpWidget(
        harness(
          const TipWidget(tip: tip),
          theme: TipThemeData(
            cardBuilder: (context, details) => GestureDetector(
              onTap: () => details.onAction(details.content.actions.single),
              child: Text('custom ${details.content.title}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TipCard), findsNothing);
      expect(find.text('custom Hello'), findsOneWidget);

      await tester.tap(find.text('custom Hello'));
      await tester.pumpAndSettle();
      expect(
        tip.status,
        const TipInvalidated(TipInvalidationReason.actionPerformed),
      );
      expect(find.text('custom Hello'), findsNothing);
    });

    testWidgets('a widget builder wins over the theme and can wrap the '
        'default card', (tester) async {
      await Tips.configure();
      await tester.pumpWidget(
        harness(
          TipWidget(
            tip: const TestTip('a', title: 'Hello'),
            cardBuilder: (context, details) => Column(
              children: [const Text('badge'), TipCard.fromDetails(details)],
            ),
          ),
          theme: TipThemeData(
            cardBuilder: (context, details) => const Text('theme card'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('theme card'), findsNothing);
      expect(find.text('badge'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('a popover builder gets the arrow edge and position', (
      tester,
    ) async {
      useScreenSize(tester);
      await Tips.configure();
      TipCardDetails? seen;
      await tester.pumpWidget(
        harness(
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 360, top: 100),
              child: PopoverTipWidget(
                tip: const TestTip('a', title: 'Hello'),
                arrowEdge: TipArrowEdge.top,
                cardBuilder: (context, details) {
                  seen = details;
                  return TipCard.fromDetails(details);
                },
                child: const SizedBox.square(dimension: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen?.isPopover, isTrue);
      expect(seen?.arrowEdge, TipArrowEdge.top);
      final card = tester.getRect(find.byType(TipCard));
      expect(card.left + seen!.arrowPosition!.value!, moreOrLessEquals(370));
    });
  });

  group('transitions', () {
    testWidgets('a custom inline transition gets the animation', (
      tester,
    ) async {
      await Tips.configure();
      TipTransitionDetails? seen;
      await tester.pumpWidget(
        harness(
          TipWidget(
            tip: const TestTip('a', title: 'Hello'),
            transitionBuilder: (context, animation, details, child) {
              seen = details;
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(seen?.isPopover, isFalse);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Hello'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
    });

    testWidgets('popover transitions start from the arrow', (tester) async {
      useScreenSize(tester);
      await Tips.configure();
      TipTransitionDetails? seen;
      await tester.pumpWidget(
        harness(
          const Center(
            child: PopoverTipWidget(
              tip: TestTip('a'),
              arrowEdge: TipArrowEdge.bottom,
              arrowAlignment: TipArrowAlignment.end,
              child: SizedBox.square(dimension: 20),
            ),
          ),
          theme: TipThemeData(
            popoverTransitionBuilder: (context, animation, details, child) {
              seen = details;
              return TipTransitions.slide(context, animation, details, child);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen?.isPopover, isTrue);
      expect(seen?.arrowAlignment, Alignment.bottomRight);
    });

    testWidgets('the built-in transitions show the tip', (tester) async {
      await Tips.configure();
      for (final transition in [
        TipTransitions.fade,
        TipTransitions.scale,
        TipTransitions.slide,
        TipTransitions.reveal,
      ]) {
        await tester.pumpWidget(
          harness(
            TipWidget(
              key: UniqueKey(),
              tip: const TestTip('a', title: 'Hello'),
              transitionBuilder: transition,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hello'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
