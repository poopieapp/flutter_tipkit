import 'dart:async';

import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/tips.dart';
import 'package:material_ui/material_ui.dart';

class TourChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Tour',
      description:
          'A group shows its tips one after another. Each tip can sit at its '
          'own place, inline or as a popover. The group resumes where the '
          'user left off.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TipWidget(
            tip: TourStartTip(),
            group: tour,
            padding: EdgeInsets.only(bottom: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopoverTipWidget(
                tip: const TourSearchTip(),
                group: tour,
                arrowEdge: TipArrowEdge.top,
                arrowAlignment: TipArrowAlignment.start,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
              PopoverTipWidget(
                tip: const TourAddTip(),
                group: tour,
                arrowEdge: TipArrowEdge.top,
                arrowAlignment: TipArrowAlignment.end,
                child: IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
      code: '''
const tour = TipGroup.ordered([TourStartTip(), TourSearchTip(), TourAddTip()]);

const TipWidget(tip: TourStartTip(), group: tour);

PopoverTipWidget(tip: const TourSearchTip(), group: tour, child: searchButton);

PopoverTipWidget(tip: const TourAddTip(), group: tour, child: addButton);
''',
    );
  }
}

class LimitChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Display limit',
      description:
          'Some tips are fine to ignore. With a display limit, a tip goes '
          'away by itself after a few showings, so it never nags. The event '
          'log below counts the showings.',
      demo: TipWidget(tip: LimitedTip(), showCloseButton: false),
      code: '''
@override
List<TipOption> get options => const [TipOption.maxDisplayCount(3)];

// And for the whole app, at most one new tip a day:
await Tips.configure(displayFrequency: TipDisplayFrequency.daily);
''',
    );
  }
}

class SuppressChapter extends StatefulWidget {
  const new({super.key});

  @override
  State<SuppressChapter> createState() => _SuppressChapterState();
}

class _SuppressChapterState extends State<SuppressChapter> {
  TipSuppression? _suppression;
  Timer? _timer;

  void _suppress() {
    setState(() => _suppression = Tips.suppress());
    _timer = Timer(const Duration(seconds: 3), _release);
  }

  void _release() {
    _suppression?.release();
    if (mounted) setState(() => _suppression = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _suppression?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuppressed = _suppression != null;
    return DemoPage(
      title: 'Suppress',
      description:
          'Suppressing hides every tip without ending any, for example while '
          'a full-screen dialog or a purchase flow is open.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TipWidget(
            tip: SuppressedTip(),
            showCloseButton: false,
            padding: EdgeInsets.only(bottom: 12),
          ),
          FilledButton.tonal(
            onPressed: isSuppressed ? null : _suppress,
            child: Text(
              isSuppressed ? 'Hidden for three seconds…' : 'Hide all tips',
            ),
          ),
        ],
      ),
      code: '''
final suppression = Tips.suppress();
// ... the dialog is open ...
suppression.release();
''',
    );
  }
}
