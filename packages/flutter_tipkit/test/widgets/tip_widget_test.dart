import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

import '../helpers.dart';
import 'harness.dart';

const _gotIt = TipAction(id: 'gotIt', label: 'Got it');

void main() {
  setUpTipTests();
  _paddingAndSliverTests();

  testWidgets('appears once tips are configured, with its content', (
    tester,
  ) async {
    const tip = TestTip('a', title: 'Hello', message: 'World');
    await tester.pumpWidget(harness(const TipWidget(tip: tip)));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);

    await Tips.configure();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(Tips.center.isDisplayed(tip), isTrue);
    expect(Tips.center.recordOf(tip)?.displayCount, 1);
  });

  testWidgets('the close button invalidates the tip and hides it', (
    tester,
  ) async {
    await Tips.configure();
    const tip = TestTip('a', title: 'Hello');
    Tip? closed;
    await tester.pumpWidget(
      harness(TipWidget(tip: tip, onClose: (tip) => closed = tip)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TipCloseButton));
    await tester.pumpAndSettle();
    expect(closed, tip);
    expect(tip.status, const TipInvalidated(TipInvalidationReason.tipClosed));
    expect(find.text('Hello'), findsNothing);
    expect(Tips.center.isDisplayed(tip), isFalse);
  });

  testWidgets('an action invalidates the tip and reports itself', (
    tester,
  ) async {
    await Tips.configure();
    const tip = TestTip('a', actions: [_gotIt]);
    TipAction? tapped;
    await tester.pumpWidget(
      harness(TipWidget(tip: tip, onAction: (_, action) => tapped = action)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(tapped, _gotIt);
    expect(
      tip.status,
      const TipInvalidated(TipInvalidationReason.actionPerformed),
    );
    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('a group view moves on to the next tip', (tester) async {
    await Tips.configure();
    const group = TipGroup.ordered([
      TestTip('a', title: 'First', actions: [_gotIt]),
      TestTip('b', title: 'Second', actions: [_gotIt]),
    ]);
    await tester.pumpWidget(harness(const TipWidget.group(group)));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('with a tip and a group, shows the tip only while current', (
    tester,
  ) async {
    await Tips.configure();
    const first = TestTip('a', title: 'First', actions: [_gotIt]);
    const second = TestTip('b', title: 'Second');
    const group = TipGroup.ordered([first, second]);
    await tester.pumpWidget(
      harness(
        const Column(
          children: [
            TipWidget(tip: first, group: group),
            TipWidget(tip: second, group: group),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('content can be provided where the tip is shown', (tester) async {
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        TipWidget(
          tip: const TestTip('a', title: 'Model'),
          content: (context, tip) => TipContent(title: 'Local ${tip.id}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Local a'), findsOneWidget);
    expect(find.text('Model'), findsNothing);
  });

  testWidgets('the theme provides the leading widget and the buttons', (
    tester,
  ) async {
    await Tips.configure();
    const tip = TestTip('a', actions: [_gotIt]);
    await tester.pumpWidget(
      harness(
        const TipWidget(tip: tip),
        theme: TipThemeData(
          leading: const Text('icon'),
          closeButtonBuilder: (context, onClose) => GestureDetector(
            onTap: onClose,
            child: const Text('custom close'),
          ),
          actionBuilder: (context, action, onPressed) => GestureDetector(
            onTap: onPressed,
            child: Text('custom ${action.label}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('icon'), findsOneWidget);
    expect(find.text('custom close'), findsOneWidget);
    expect(find.text('custom Got it'), findsOneWidget);

    await tester.tap(find.text('custom Got it'));
    await tester.pumpAndSettle();
    expect(tip.status, isA<TipInvalidated>());
  });

  testWidgets('showCloseButton: false hides the close button', (tester) async {
    await Tips.configure();
    await tester.pumpWidget(
      harness(const TipWidget(tip: TestTip('a'), showCloseButton: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TipCloseButton), findsNothing);
  });

  testWidgets('suppression hides the tip and brings it back', (tester) async {
    await Tips.configure();
    await tester.pumpWidget(
      harness(const TipWidget(tip: TestTip('a', title: 'Hello'))),
    );
    await tester.pumpAndSettle();
    final suppression = Tips.suppress();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
    suppression.release();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('removing the view ends the display', (tester) async {
    await Tips.configure();
    const tip = TestTip('a', options: [TipOption.maxDisplayCount(1)]);
    await tester.pumpWidget(harness(const TipWidget(tip: tip)));
    await tester.pumpAndSettle();
    expect(Tips.center.isDisplayed(tip), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(Tips.center.isDisplayed(tip), isFalse);
    expect(
      tip.status,
      const TipInvalidated(TipInvalidationReason.displayCountExceeded),
    );
  });
}

void _paddingAndSliverTests() {
  testWidgets('padding takes no space while the tip is hidden', (tester) async {
    await Tips.configure();
    const tip = TestTip('a', title: 'Hello');
    await tester.pumpWidget(
      harness(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TipWidget(tip: tip, padding: EdgeInsets.only(bottom: 12)),
            SizedBox(key: Key('below'), height: 10),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cardBottom = tester.getRect(find.byType(TipCard)).bottom;
    expect(
      tester.getTopLeft(find.byKey(const Key('below'))).dy,
      moreOrLessEquals(cardBottom + 12),
    );

    tip.invalidate(TipInvalidationReason.tipClosed);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('below'))).dy, 0);
  });

  testWidgets('SliverTipWidget has no extent while hidden', (tester) async {
    await Tips.configure();
    const tip = TestTip('a', title: 'Hello');
    await tester.pumpWidget(
      harness(
        const CustomScrollView(
          slivers: [
            SliverTipWidget(tip: tip, padding: EdgeInsets.all(8)),
            SliverToBoxAdapter(child: SizedBox(key: Key('below'), height: 10)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    final cardBottom = tester.getRect(find.byType(TipCard)).bottom;
    expect(
      tester.getTopLeft(find.byKey(const Key('below'))).dy,
      moreOrLessEquals(cardBottom + 8),
    );

    tip.invalidate(TipInvalidationReason.tipClosed);
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
    expect(tester.getTopLeft(find.byKey(const Key('below'))).dy, 0);
  });

  testWidgets('SliverTipWidget.group shows the current tip', (tester) async {
    await Tips.configure();
    await tester.pumpWidget(
      harness(
        const CustomScrollView(
          slivers: [
            SliverTipWidget.group(
              TipGroup.ordered([TestTip('a', title: 'First')]),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
  });
}
