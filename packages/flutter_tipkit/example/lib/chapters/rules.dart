import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/tips.dart';
import 'package:material_ui/material_ui.dart';

class EventChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Events',
      description:
          'An event counts something the user does. A rule on it decides '
          'when the tip is worth showing: here, after the third like.',
      demo: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.favorite),
            onPressed: liked.donate,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: Tips.center,
              builder: (context, _) =>
                  Text('Liked ${liked.donations.count} times'),
            ),
          ),
          PopoverTipWidget(
            tip: const SaveTip(),
            arrowEdge: TipArrowEdge.top,
            arrowAlignment: TipArrowAlignment.end,
            child: IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {},
            ),
          ),
        ],
      ),
      code: '''
const liked = TipEvent('liked');

liked.donate(); // on each like

@override
List<TipRule> get rules => [
  TipRule.event(liked, (donations) => donations.count >= 3),
];
''',
    );
  }
}

class ParameterChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Parameters',
      description:
          'A parameter brings app state into the rules. Two tips watch the '
          'same parameter: one shows while it is false, the other while it '
          'is true.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: Tips.center,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Signed in'),
              value: isSignedIn.value,
              onChanged: (value) => isSignedIn.value = value,
            ),
          ),
          const TipWidget(tip: SignInTip(), showCloseButton: false),
          const TipWidget(tip: SyncTip(), showCloseButton: false),
        ],
      ),
      code: '''
const isSignedIn = TipParameter<bool>('isSignedIn', false);

isSignedIn.value = true; // when it changes

// SignInTip
TipRule.not(TipRule.parameter(isSignedIn, (signedIn) => signedIn));

// SyncTip
TipRule.parameter(isSignedIn, (signedIn) => signedIn);
''',
    );
  }
}

class TimingChapter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Timing',
      description:
          'A tip can wait for another one to end, and then some more. The '
          'rule wakes up by itself when its time comes, no polling needed.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TipWidget(tip: FirstStepTip()),
          TipWidget(tip: FollowUpTip()),
          SizedBox(height: 8),
          Text('Tap "Got it", then wait five seconds.'),
        ],
      ),
      code: '''
@override
List<TipRule> get rules => [
  TipRule.tipInvalidated(
    const FirstStepTip(),
    minAge: const Duration(seconds: 5),
  ),
];
''',
    );
  }
}
