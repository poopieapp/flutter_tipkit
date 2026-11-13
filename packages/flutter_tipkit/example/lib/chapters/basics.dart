import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/tips.dart';
import 'package:material_ui/material_ui.dart';

class InlineChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Inline tip',
      description:
          'A tip in the layout. It takes no space until it shows, grows in, '
          'and shrinks away when it ends. Closed, it stays closed, even '
          'after a restart with a persistent datastore.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TipWidget(tip: WelcomeTip(), padding: EdgeInsets.only(bottom: 12)),
          Text('The content below the tip moves up when it goes away.'),
        ],
      ),
      code: '''
class WelcomeTip extends Tip {
  const WelcomeTip();

  @override
  String get id => 'welcome';

  @override
  TipContent get content => const TipContent(
    title: 'Tips can be this simple',
    message: 'An id and a text.',
  );
}

const TipWidget(tip: WelcomeTip());
''',
    );
  }
}

class PopoverChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Popover tip',
      description:
          'A tip over the screen, pointing at its widget. Three of them are '
          'available here, but only one shows at a time: close one, and the '
          'next one takes its turn.',
      demo: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopoverTipWidget(
            tip: const ShareTip(),
            arrowEdge: TipArrowEdge.top,
            arrowAlignment: TipArrowAlignment.start,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ),
          PopoverTipWidget(
            tip: const SearchTip(),
            arrowEdge: TipArrowEdge.top,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
          ),
          PopoverTipWidget(
            tip: const FilterTip(),
            arrowEdge: TipArrowEdge.end,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.filter_list),
              onPressed: () {},
            ),
          ),
        ],
      ),
      code: '''
PopoverTipWidget(
  tip: const ShareTip(),
  // The edge with the arrow: top opens below the button.
  arrowEdge: TipArrowEdge.top,
  arrowAlignment: TipArrowAlignment.start,
  child: IconButton(icon: Icon(Icons.share), onPressed: share),
);
''',
    );
  }
}

class ActionsChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Actions',
      description:
          'Actions are buttons on the tip. By default an action ends the '
          'tip, since "Next" and "Got it" end most tips. One that should '
          'not, sets invalidatesTip to false.',
      demo: TipWidget(
        tip: const ActionsTip(),
        onAction: (tip, action) {
          if (action.id != 'learnMore') return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('"Learn more" tapped, tip kept')),
            );
        },
      ),
      code: '''
TipContent(
  title: 'Tips can have buttons',
  actions: [
    TipAction(id: 'learnMore', label: 'Learn more', invalidatesTip: false),
    TipAction(id: 'gotIt', label: 'Got it'),
  ],
);

TipWidget(
  tip: const ActionsTip(),
  onAction: (tip, action) {
    if (action.id == 'learnMore') openHelp();
  },
);
''',
    );
  }
}
