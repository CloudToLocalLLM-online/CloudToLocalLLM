import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tunnel_state.dart';
import '../config/theme.dart';

class TunnelDetailsCard extends StatelessWidget {
  final TunnelState tunnelState;

  const TunnelDetailsCard({super.key, required this.tunnelState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnectionStats(),
        const SizedBox(height: 16),
        _buildTechnicalInfo(),
      ],
    );
  }

  Widget _buildConnectionStats() {
    final stats = tunnelState.stats;
    final quality = tunnelState.quality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connection Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3,
          children: [
            _buildStatItem('Status',
                tunnelState.isConnected ? 'Connected' : 'Disconnected'),
            _buildStatItem('Quality', quality.label,
                color: _getQualityColor(quality)),
            _buildStatItem(
                'Duration', _formatDuration(tunnelState.connectionDuration)),
            _buildStatItem('Latency',
                stats != null ? '${stats.averageLatencyMs} ms' : 'N/A'),
            _buildStatItem('Transferred',
                stats != null ? _formatBytes(stats.bytesTransferred) : 'N/A'),
            _buildStatItem('Received',
                stats != null ? _formatBytes(stats.bytesReceived) : 'N/A'),
            _buildStatItem(
                'Success Rate',
                stats != null
                    ? '${(stats.successRate * 100).toStringAsFixed(1)}%'
                    : 'N/A'),
          ],
        ),
      ],
    );
  }

  Widget _buildTechnicalInfo() {
    return ExpansionTile(
      title: const Text(
        'Technical Info',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      children: [
        _buildInfoRow('Tunnel ID', tunnelState.tunnelId ?? 'N/A'),
        _buildInfoRow(
            'Tunnel Port', tunnelState.tunnelPort?.toString() ?? 'N/A'),
        _buildInfoRow(
            'Last Request',
            tunnelState.stats != null
                ? DateFormat.yMd()
                    .add_Hms()
                    .format(tunnelState.stats!.lastRequestAt)
                : 'N/A'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppTheme.textColorLight, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textColorLight)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getQualityColor(TunnelConnectionQuality quality) {
    switch (quality) {
      case TunnelConnectionQuality.excellent:
        return Colors.green;
      case TunnelConnectionQuality.good:
        return Colors.lightGreen;
      case TunnelConnectionQuality.fair:
        return Colors.orange;
      case TunnelConnectionQuality.poor:
        return Colors.red;
      default:
        return AppTheme.textColor;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(2)} B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
