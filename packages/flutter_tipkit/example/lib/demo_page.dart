import 'package:flutter/material.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';

/// The latest tip events, newest first, fed by `Tips.configure(onEvent:)`.
final eventLog = ValueNotifier<List<String>>(const []);

/// Adds [event] to the [eventLog].
void logTipEvent(TipLifecycleEvent event) {
  final line = switch (event) {
    TipShownEvent(:final tip, :final displayCount) =>
      'shown       ${tip.id} (#$displayCount)',
    TipActionEvent(:final tip, :final action) =>
      'action      ${tip.id} → ${action.id}',
    TipInvalidatedEvent(:final tip, :final reason) =>
      'invalidated ${tip.id} → ${reason.name}',
  };
  eventLog.value = [line, ...eventLog.value.take(49)];
}

/// Clears every tip's state and the event log.
Future<void> resetDemo() async {
  await Tips.resetDatastore();
  eventLog.value = const [];
}

/// One chapter of the demo: what it shows, the demo itself, and its code.
class DemoPage extends StatelessWidget {
  const DemoPage({
    required this.title,
    required this.description,
    required this.demo,
    required this.code,
    super.key,
  });

  final String title;
  final String description;
  final Widget demo;
  final String code;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [ResetButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(description, style: textTheme.bodyLarge),
          const SizedBox(height: 16),
          Card.outlined(
            child: Padding(padding: const EdgeInsets.all(16), child: demo),
          ),
          const SizedBox(height: 24),
          Text('How', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          CodeBlock(code),
          const SizedBox(height: 24),
          Text('Events', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          const EventLogView(maxLines: 4),
        ],
      ),
    );
  }
}

/// Starts every tip over.
class ResetButton extends StatelessWidget {
  const ResetButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.restart_alt),
      tooltip: 'Reset all tips',
      onPressed: () async {
        await resetDemo();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Every tip starts over')),
          );
      },
    );
  }
}

/// Source code, in a monospace box that scrolls sideways.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          code.trim(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['Courier New', 'Courier'],
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// The latest [eventLog] lines.
class EventLogView extends StatelessWidget {
  const EventLogView({this.maxLines, super.key});

  /// How many lines to show; all of them when null.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: eventLog,
      builder: (context, lines, _) {
        final shown = maxLines == null ? lines : lines.take(maxLines!).toList();
        return CodeBlock(
          shown.isEmpty
              ? 'Nothing yet. Interact with the tips.'
              : shown.join('\n'),
        );
      },
    );
  }
}
