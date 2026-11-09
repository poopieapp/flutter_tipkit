import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

import '../helpers.dart';
import 'harness.dart';

const _hidden = TestTip('hidden', title: 'Hidden tab tip');
const _visible = TestTip('visible', title: 'Visible tab tip');

/// Two tabs kept alive side by side, like an IndexedStack-based tab bar:
/// only [activeTab] has tickers enabled.
Widget _tabs({required int activeTab}) {
  Widget tab(int index, Tip tip, Offset at) {
    return TickerMode(
      enabled: index == activeTab,
      child: Offstage(
        offstage: index != activeTab,
        child: Stack(
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              child: PopoverTipWidget(
                tip: tip,
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Stack(
    children: [
      Positioned.fill(child: tab(0, _hidden, const Offset(100, 100))),
      Positioned.fill(child: tab(1, _visible, const Offset(200, 400))),
    ],
  );
}

void main() {
  setUpTipTests();

  testWidgets('a popover in an inactive tab neither shows nor blocks the '
      'active tab', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    await tester.pumpWidget(harness(_tabs(activeTab: 1)));
    await tester.pumpAndSettle();

    expect(find.text('Visible tab tip'), findsOneWidget);
    expect(find.text('Hidden tab tip'), findsNothing);
    expect(Tips.center.isDisplayed(_hidden), isFalse);
    expect(Tips.center.recordOf(_hidden), isNull);
  });

  testWidgets('switching tabs hands the popover over', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    // The overlay keeps its first entry, so the tab changes through a
    // notifier rather than a new widget tree.
    final activeTab = ValueNotifier(1);
    addTearDown(activeTab.dispose);
    await tester.pumpWidget(
      harness(
        ValueListenableBuilder(
          valueListenable: activeTab,
          builder: (_, tab, _) => _tabs(activeTab: tab),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visible tab tip'), findsOneWidget);

    activeTab.value = 0;
    await tester.pumpAndSettle();
    expect(find.text('Visible tab tip'), findsNothing);
    expect(find.text('Hidden tab tip'), findsOneWidget);
    expect(_visible.status, TipStatus.available, reason: 'not invalidated');
  });

  testWidgets('no barrier is left behind when the tab changes', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    Tips.hideAllTipsForTesting();
    var tapped = 0;
    await tester.pumpWidget(
      harness(
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tapped++,
                child: const SizedBox.expand(),
              ),
            ),
            _tabs(activeTab: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 780));
    expect(tapped, 1);
  });

  testWidgets('a pushed route hides the popover under it, and popping '
      'brings it back', (tester) async {
    useScreenSize(tester);
    await Tips.configure();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: kScreenSize),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Navigator(
            key: navigator,
            onGenerateRoute: (_) => PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const Center(
                child: PopoverTipWidget(
                  tip: TestTip('a', title: 'Under'),
                  child: SizedBox.square(dimension: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Under'), findsOneWidget);

    var tappedOnTop = false;
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tappedOnTop = true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Under'), findsNothing);
    await tester.tapAt(const Offset(20, 780));
    expect(tappedOnTop, isTrue);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Under'), findsOneWidget);
  });

  testWidgets('an inline tip in an inactive tab does not count displays', (
    tester,
  ) async {
    await Tips.configure();
    const tip = TestTip('inline', title: 'Inline');
    await tester.pumpWidget(
      harness(const TickerMode(enabled: false, child: TipWidget(tip: tip))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inline'), findsNothing);
    expect(Tips.center.recordOf(tip), isNull);
  });
}
