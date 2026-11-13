import 'package:flutter_tipkit/flutter_tipkit.dart';

// Every tip of the demo, from the simplest to the most involved. Each one is
// plain data: an id, its text, and when and how it may show.

// --- Basics ------------------------------------------------------------------

/// The simplest tip: an id and a text, no rules.
class WelcomeTip extends Tip {
  const WelcomeTip();

  @override
  String get id => 'welcome';

  @override
  TipContent get content => const TipContent(
    title: 'Tips can be this simple',
    message: 'An id and a text. Close it with the cross.',
  );
}

/// A popover on the share button.
class ShareTip extends Tip {
  const ShareTip();

  @override
  String get id => 'share';

  @override
  TipContent get content => const TipContent(
    title: 'Share it',
    message: 'Popovers point at their widget. Tap outside to close this one.',
  );
}

/// A popover on the search button, waiting for the share tip.
class SearchTip extends Tip {
  const SearchTip();

  @override
  String get id => 'search';

  @override
  TipContent get content => const TipContent(
    title: 'Then search',
    message: 'Only one popover shows at a time, so this one waited its turn.',
  );
}

/// A popover on the filter button, waiting for the search tip.
class FilterTip extends Tip {
  const FilterTip();

  @override
  String get id => 'filter';

  @override
  TipContent get content => const TipContent(
    title: 'And filter',
    message: 'The arrow can sit on any edge. This one opens beside its button.',
  );
}

/// A tip with two actions: one keeps the tip, the other ends it.
class ActionsTip extends Tip {
  const ActionsTip();

  @override
  String get id => 'actions';

  @override
  TipContent get content => const TipContent(
    title: 'Tips can have buttons',
    message: '"Learn more" keeps this tip. "Got it" ends it.',
    actions: [
      TipAction(id: 'learnMore', label: 'Learn more', invalidatesTip: false),
      TipAction(id: 'gotIt', label: 'Got it'),
    ],
  );
}

// --- Rules -------------------------------------------------------------------

/// Donated each time the like button is tapped.
const liked = TipEvent('liked');

/// Shows after three likes.
class SaveTip extends Tip {
  const SaveTip();

  @override
  String get id => 'save';

  @override
  TipContent get content => const TipContent(
    title: 'You like this one',
    message: 'Three likes in. Save it so you find it again.',
    actions: [TipAction(id: 'gotIt', label: 'Got it')],
  );

  @override
  List<TipRule> get rules => [
    TipRule.event(liked, (donations) => donations.count >= 3),
  ];
}

/// Whether the user is signed in, set by the switch.
const isSignedIn = TipParameter<bool>('isSignedIn', false);

/// Shows while signed out.
class SignInTip extends Tip {
  const SignInTip();

  @override
  String get id => 'signIn';

  @override
  TipContent get content => const TipContent(
    title: 'Sign in to sync',
    message: 'This tip shows while the parameter is false.',
  );

  @override
  List<TipRule> get rules => [
    TipRule.not(TipRule.parameter(isSignedIn, (signedIn) => signedIn)),
  ];
}

/// Shows while signed in.
class SyncTip extends Tip {
  const SyncTip();

  @override
  String get id => 'sync';

  @override
  TipContent get content => const TipContent(
    title: 'Your notes now sync',
    message: 'This one shows while it is true. Flip the switch back and forth.',
  );

  @override
  List<TipRule> get rules => [
    TipRule.parameter(isSignedIn, (signedIn) => signedIn),
  ];
}

/// The first of two tips, some time apart.
class FirstStepTip extends Tip {
  const FirstStepTip();

  @override
  String get id => 'firstStep';

  @override
  TipContent get content => const TipContent(
    title: 'Close me',
    message: 'The next tip comes five seconds after this one ends.',
    actions: [TipAction(id: 'gotIt', label: 'Got it')],
  );
}

/// Five seconds after the first step ends.
class FollowUpTip extends Tip {
  const FollowUpTip();

  @override
  String get id => 'followUp';

  @override
  TipContent get content => const TipContent(
    title: 'Five seconds later',
    message:
        'Time-based rules wake up by themselves. In an app this could be '
        'a day later, on another screen.',
  );

  @override
  List<TipRule> get rules => [
    TipRule.tipInvalidated(
      const FirstStepTip(),
      minAge: const Duration(seconds: 5),
    ),
  ];
}

// --- Flow --------------------------------------------------------------------

/// The first step of the tour, inline.
class TourStartTip extends Tip {
  const TourStartTip();

  @override
  String get id => 'tourStart';

  @override
  TipContent get content => const TipContent(
    title: 'A three-step tour',
    message: 'Each step shows at its own place, one after another.',
    actions: [TipAction(id: 'next', label: 'Next')],
  );
}

/// The second step of the tour, on the search button.
class TourSearchTip extends Tip {
  const TourSearchTip();

  @override
  String get id => 'tourSearch';

  @override
  TipContent get content => const TipContent(
    title: 'Step two',
    message: 'Leave the page and come back: the tour resumes here.',
    actions: [TipAction(id: 'next', label: 'Next')],
  );
}

/// The last step of the tour, on the add button.
class TourAddTip extends Tip {
  const TourAddTip();

  @override
  String get id => 'tourAdd';

  @override
  TipContent get content => const TipContent(
    title: 'Last step',
    message: 'The group keeps no state: it follows from the tips.',
    actions: [TipAction(id: 'done', label: 'Done')],
  );
}

/// The tour: one tip after another, each at its own place.
const tour = TipGroup.ordered([TourStartTip(), TourSearchTip(), TourAddTip()]);

/// Goes away by itself after three displays.
class LimitedTip extends Tip {
  const LimitedTip();

  @override
  String get id => 'limited';

  @override
  TipContent get content => const TipContent(
    title: 'I show three times',
    message:
        'Go back and open this page again. After the third time I stay '
        'away, even without being closed.',
  );

  @override
  List<TipOption> get options => const [TipOption.maxDisplayCount(3)];
}

/// Hidden for a while by the suppress button.
class SuppressedTip extends Tip {
  const SuppressedTip();

  @override
  String get id => 'suppressed';

  @override
  TipContent get content => const TipContent(
    title: 'Hidden, not ended',
    message:
        'Suppressing hides every tip for a while, for example behind a '
        'full-screen dialog. They come back afterwards.',
  );
}

// --- Look --------------------------------------------------------------------

/// An inline tip in the theming page.
class ThemedInlineTip extends Tip {
  const ThemedInlineTip();

  @override
  String get id => 'themedInline';

  @override
  TipContent get content => const TipContent(
    title: 'Make it yours',
    message: 'Switch the styles above: the same tips, drawn three ways.',
    actions: [TipAction(id: 'gotIt', label: 'Got it')],
  );
}

/// A popover in the theming page.
class ThemedPopoverTip extends Tip {
  const ThemedPopoverTip();

  @override
  String get id => 'themedPopover';

  @override
  TipContent get content => const TipContent(
    title: 'Popovers too',
    message: 'Colors, gradients, arrows, or a card of your own.',
  );
}

/// Points at the inspector from the home screen.
class InspectorTip extends Tip {
  const InspectorTip();

  @override
  String get id => 'inspector';

  @override
  TipContent get content => const TipContent(
    title: 'Watch the tips',
    message: 'See every tip and event live in the inspector.',
  );
}

/// Every tip, for the inspector.
const allTips = <Tip>[
  WelcomeTip(),
  ShareTip(),
  SearchTip(),
  FilterTip(),
  ActionsTip(),
  SaveTip(),
  SignInTip(),
  SyncTip(),
  FirstStepTip(),
  FollowUpTip(),
  TourStartTip(),
  TourSearchTip(),
  TourAddTip(),
  LimitedTip(),
  SuppressedTip(),
  ThemedInlineTip(),
  ThemedPopoverTip(),
  InspectorTip(),
];
