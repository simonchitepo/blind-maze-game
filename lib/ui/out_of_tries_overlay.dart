import 'package:flutter/material.dart';
import 'glass_panel.dart';

class OutOfTriesOverlay extends StatelessWidget {
  final int level;
  final int maxTries;
  final VoidCallback onRestart;

  const OutOfTriesOverlay({
    super.key,
    required this.level,
    required this.maxTries,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 34, color: Color(0xFFFF6B81)),
            const SizedBox(height: 10),
            Text(
              'Out of tries',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFE6E6F0),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Level $level uses a $maxTries-try limit.\nRestart to try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB9B9C6), height: 1.25),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 180,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart level'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
