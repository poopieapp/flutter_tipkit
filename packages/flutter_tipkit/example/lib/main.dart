import 'package:flutter/material.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

/// Counted each time a note is added.
const addedNote = TipEvent('addedNote');

/// Set once the user opens the settings.
const openedSettings = TipParameter<bool>('openedSettings', false);

/// Explains the add button, inline at the top of the list.
class AddNoteTip extends Tip {
  const AddNoteTip();

  @override
  String get id => 'addNote';

  @override
  TipContent get content => const TipContent(
    title: 'Add your first note',
    message: 'Tap the + button to write something down.',
  );

  // Gone once a note was added.
  @override
  List<TipRule> get rules => [
    TipRule.event(addedNote, (donations) => donations.count == 0),
  ];
}

/// Points at the favorite button after three notes.
class FavoriteTip extends Tip {
  const FavoriteTip();

  @override
  String get id => 'favorite';

  @override
  TipContent get content => const TipContent(
    title: 'Keep the good ones',
    message: 'Star a note to pin it to the top.',
    actions: [TipAction(id: 'gotIt', label: 'Got it')],
  );

  @override
  List<TipRule> get rules => [
    TipRule.event(addedNote, (donations) => donations.count >= 3),
  ];

  @override
  List<TipOption> get options => const [TipOption.maxDisplayCount(3)];
}

/// The settings tour, one tip after another.
class ThemeTip extends Tip {
  const ThemeTip();

  @override
  String get id => 'theme';

  @override
  TipContent get content => const TipContent(
    title: 'Pick a theme',
    message: 'Light, dark, or follow the system.',
    actions: [TipAction(id: 'next', label: 'Next')],
  );

  @override
  List<TipRule> get rules => [
    TipRule.parameter(openedSettings, (opened) => opened),
  ];
}

/// The second tip of the settings tour.
class BackupTip extends Tip {
  const BackupTip();

  @override
  String get id => 'backup';

  @override
  TipContent get content => const TipContent(
    title: 'Back up your notes',
    message: 'Turn on backups so a new phone starts with all your notes.',
    actions: [TipAction(id: 'done', label: 'Done')],
  );
}

const settingsTour = TipGroup.ordered([ThemeTip(), BackupTip()]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pass a persistent datastore, such as the one in
  // flutter_tipkit_shared_preferences, to keep tips across launches.
  await Tips.configure(onEvent: (event) => debugPrint('Tip event: $event'));
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_tipkit',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      builder: (context, child) => TipTheme(
        data: TipThemeData(
          backgroundColor: Theme.of(context).colorScheme.surface,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          actionStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          leading: const Icon(Icons.lightbulb_outline),
        ),
        child: child!,
      ),
      home: const NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<String> _notes = [];

  void _addNote() {
    setState(() => _notes.add('Note ${_notes.length + 1}'));
    addedNote.donate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          PopoverTipWidget(
            tip: const FavoriteTip(),
            arrowEdge: TipArrowEdge.top,
            arrowAlignment: TipArrowAlignment.end,
            child: IconButton(
              icon: const Icon(Icons.star_outline),
              onPressed: () {},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              openedSettings.value = true;
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              const PopupMenuItem(
                onTap: Tips.resetDatastore,
                child: Text('Reset tips'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TipWidget(tip: AddNoteTip()),
          for (final note in _notes) ListTile(title: Text(note)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            // The tour's tips show at different places, one after another.
            child: TipWidget(tip: ThemeTip(), group: settingsTour),
          ),
          PopoverTipWidget(
            tip: const BackupTip(),
            group: settingsTour,
            child: SwitchListTile(
              title: const Text('Backups'),
              value: false,
              onChanged: (_) {},
            ),
          ),
          const ListTile(title: Text('Theme')),
        ],
      ),
    );
  }
}
