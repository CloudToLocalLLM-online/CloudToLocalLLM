import 'package:flutter/material.dart';
import '../models/platform_config.dart';
import '../services/platform_detection_service.dart';

/// Widget that displays platform-specific troubleshooting information
class PlatformTroubleshootingWidget extends StatelessWidget {
  final PlatformType platform;
  final PlatformDetectionService platformService;

  const PlatformTroubleshootingWidget({
    super.key,
    required this.platform,
    required this.platformService,
  });

  @override
  Widget build(BuildContext context) {
    final platformConfig = platformService.getPlatformConfig(platform);

    if (platformConfig == null || platformConfig.troubleshootingGuides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: Text('${platform.displayName} Troubleshooting'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Common Issues & Solutions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ...platformConfig.troubleshootingGuides.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }),
                if (platformConfig.requiredDependencies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Required Dependencies',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...platformConfig.requiredDependencies.map((dependency) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(dependency)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}