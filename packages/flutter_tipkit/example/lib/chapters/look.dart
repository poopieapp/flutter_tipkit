import 'package:flutter/material.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/tips.dart';

enum _Style { plain, styled, custom }

class ThemingChapter extends StatefulWidget {
  const ThemingChapter({super.key});

  @override
  State<ThemingChapter> createState() => _ThemingChapterState();
}

class _ThemingChapterState extends State<ThemingChapter> {
  _Style _style = _Style.styled;

  @override
  Widget build(BuildContext context) {
    final base = TipTheme.of(context);
    final theme = switch (_style) {
      _Style.plain => base,
      _Style.styled => base.copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF8E24AA)],
        ),
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(20),
        arrowShape: const TipArrowShape.rounded(size: Size(24, 12)),
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        messageStyle: const TextStyle(color: Color(0xE6FFFFFF)),
        actionStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionDividerColor: const Color(0x33FFFFFF),
        leading: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      _Style.custom => base.copyWith(
        cardBuilder: (context, details) => _CustomCard(details: details),
      ),
    };

    return DemoPage(
      title: 'Theming',
      description:
          'The same two tips, drawn three ways: the default card, restyled '
          'with a theme, and replaced by a card of your own. The tips still '
          'decide when they show; the theme only draws.',
      demo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Style>(
            segments: const [
              ButtonSegment(value: _Style.plain, label: Text('Default')),
              ButtonSegment(value: _Style.styled, label: Text('Styled')),
              ButtonSegment(value: _Style.custom, label: Text('Own card')),
            ],
            selected: {_style},
            onSelectionChanged: (selection) =>
                setState(() => _style = selection.first),
          ),
          const SizedBox(height: 16),
          TipTheme(
            data: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TipWidget(
                  tip: ThemedInlineTip(),
                  padding: EdgeInsets.only(bottom: 16),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopoverTipWidget(
                    tip: const ThemedPopoverTip(),
                    arrowEdge: TipArrowEdge.top,
                    arrowAlignment: TipArrowAlignment.start,
                    child: IconButton.filledTonal(
                      icon: const Icon(Icons.palette),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      code: '''
TipTheme(
  data: TipThemeData(
    gradient: LinearGradient(colors: [indigo, purple]),
    borderRadius: BorderRadius.circular(20),
    arrowShape: TipArrowShape.rounded(size: Size(24, 12)),
    titleStyle: TextStyle(color: Colors.white),
    // Or draw the whole card yourself:
    cardBuilder: (context, details) => MyCard(details),
  ),
  child: child,
);
''',
    );
  }
}

/// A card of the app's own, from the tip's details.
class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.details});

  final TipCardDetails details;

  @override
  Widget build(BuildContext context) {
    final content = details.content;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: details.isPopover ? 6 : 0,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(content.title, style: textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close',
                  onPressed: details.onClose,
                ),
              ],
            ),
            if (content.message case final message?)
              Padding(
                padding: const EdgeInsets.only(left: 34, right: 8),
                child: Text(message, style: textTheme.bodyMedium),
              ),
            if (content.actions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  children: [
                    for (final action in content.actions)
                      TextButton(
                        onPressed: () => details.onAction(action),
                        child: Text(action.label),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
