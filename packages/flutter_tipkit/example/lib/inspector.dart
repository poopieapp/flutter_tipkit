import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_example/demo_page.dart';
import 'package:flutter_tipkit_example/tips.dart';
import 'package:material_ui/material_ui.dart';

/// Every tip's status and the event log, live.
class InspectorScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspector'),
        actions: const [ResetButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tips.center notifies on every change, so any widget can follow '
            'the tips. This screen lists each tip with its status.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: Tips.center,
            builder: (context, _) => Card.outlined(
              child: Column(
                children: [
                  for (final tip in allTips)
                    ListTile(
                      dense: true,
                      title: Text(tip.id),
                      trailing: _StatusChip(status: tip.status),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Events', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          const EventLogView(),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const new({required this.status});

  final TipStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      TipPending() => ('pending', colors.outline),
      TipAvailable() => ('available', colors.primary),
      TipInvalidated(:final reason) => (reason.name, colors.tertiary),
    };
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}
