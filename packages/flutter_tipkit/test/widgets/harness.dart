import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

/// The screen size of the widget tests.
const kScreenSize = Size(400, 800);

/// Wraps [child] in what tips need: text direction, a text style, media
/// query and an overlay.
Widget harness(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  TipThemeData? theme,
}) {
  var content = child;
  if (theme != null) content = TipTheme(data: theme, child: content);
  return MediaQuery(
    data: const MediaQueryData(size: kScreenSize),
    child: Directionality(
      textDirection: direction,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
        child: Overlay(initialEntries: [OverlayEntry(builder: (_) => content)]),
      ),
    ),
  );
}

/// Sets the test window to [kScreenSize] and resets the tip system around
/// each test.
void setUpTipTests() {
  setUp(Tips.resetForTesting);
  tearDown(Tips.resetForTesting);
}

/// Sets the test window to [kScreenSize] for the current test.
void useScreenSize(WidgetTester tester) {
  tester.view
    ..physicalSize = kScreenSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
