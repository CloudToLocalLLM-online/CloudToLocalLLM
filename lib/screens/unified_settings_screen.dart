import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lightweight placeholder for the unified settings experience while the
/// redesigned implementation is being completed.
class UnifiedSettingsScreen extends StatelessWidget {
  final String? initialSection;

  const UnifiedSettingsScreen({super.key, this.initialSection});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.tune, size: 56, color: Color(0xFF6e8efb)),
              const SizedBox(height: 16),
              Text(
                'Settings Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We are wrapping up the revamped settings experience to match '
                'the new chat interface. In the meantime, you can manage '
                'critical configuration from the desktop application.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (kIsWeb)
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Return to Home'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
