import 'package:flutter/material.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/chapters/basics.dart';
import 'package:flutter_tipkit_example/chapters/flow.dart';
import 'package:flutter_tipkit_example/chapters/look.dart';
import 'package:flutter_tipkit_example/chapters/rules.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/inspector.dart';
import 'package:flutter_tipkit_example/tips.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In an app, pass a persistent datastore, such as the one in
  // flutter_tipkit_shared_preferences. The demo starts over on every load.
  await Tips.configure(onEvent: logTipEvent);
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_tipkit demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;
        return ColoredBox(
          color: colors.surfaceContainerHighest,
          // Keeps the demo phone-sized in a wide browser window.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TipTheme(
                data: TipThemeData(
                  backgroundColor: colors.surface,
                  borderSide: BorderSide(color: colors.outlineVariant),
                  actionStyle: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  leading: const Icon(Icons.lightbulb_outline),
                ),
                child: child!,
              ),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}

/// A chapter in the menu.
class _Chapter {
  const _Chapter(this.title, this.subtitle, this.page);

  final String title;
  final String subtitle;
  final Widget page;
}

const _sections = <(String, List<_Chapter>)>[
  (
    'Basics',
    [
      _Chapter(
        'Inline tip',
        'The simplest tip, in the layout',
        InlineChapter(),
      ),
      _Chapter(
        'Popover tip',
        'Pointing at a widget, one at a time',
        PopoverChapter(),
      ),
      _Chapter('Actions', 'Buttons that keep or end a tip', ActionsChapter()),
    ],
  ),
  (
    'Rules',
    [
      _Chapter(
        'Events',
        'After something happened three times',
        EventChapter(),
      ),
      _Chapter(
        'Parameters',
        'While the app is in some state',
        ParameterChapter(),
      ),
      _Chapter('Timing', 'Some time after another tip', TimingChapter()),
    ],
  ),
  (
    'Flow',
    [
      _Chapter('Tour', 'Steps at different places, in order', TourChapter()),
      _Chapter(
        'Display limit',
        'Goes away after three displays',
        LimitChapter(),
      ),
      _Chapter('Suppress', 'Hide every tip for a while', SuppressChapter()),
    ],
  ),
  (
    'Look',
    [
      _Chapter(
        'Theming',
        'From colors to a card of your own',
        ThemingChapter(),
      ),
    ],
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_tipkit'),
        actions: [
          PopoverTipWidget(
            tip: const InspectorTip(),
            arrowEdge: TipArrowEdge.top,
            arrowAlignment: TipArrowAlignment.end,
            child: IconButton(
              icon: const Icon(Icons.manage_search),
              tooltip: 'Inspector',
              onPressed: () {
                const InspectorTip().invalidate(
                  TipInvalidationReason.actionPerformed,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const InspectorScreen(),
                  ),
                );
              },
            ),
          ),
          const ResetButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Contextual feature tips for Flutter. Each chapter shows one '
              'feature, from a one-line tip to tours and custom themes.',
              style: textTheme.bodyLarge,
            ),
          ),
          for (final (index, (section, chapters)) in _sections.indexed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '${index + 1}. $section',
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            for (final chapter in chapters)
              ListTile(
                title: Text(chapter.title),
                subtitle: Text(chapter.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => chapter.page)),
              ),
          ],
        ],
      ),
    );
  }
}
