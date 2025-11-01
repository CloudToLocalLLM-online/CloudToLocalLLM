import 'package:flutter/material.dart';
import '../../models/tunnel_state.dart';
import '../../config/theme.dart';

/// Modern tunnel status card component
/// 
/// Displays tunnel connection status with clear visual indicators
class TunnelStatusCard extends StatelessWidget {
  final TunnelState state;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onTest;

  const TunnelStatusCard({
    super.key,
    required this.state,
    this.onConnect,
    this.onDisconnect,
    this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildStatusIndicator(context),
            if (state.hasError) ...[
              const SizedBox(height: 12),
              _buildError(context),
            ],
            const SizedBox(height: 16),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.settings_ethernet,
          color: AppTheme.primaryColor,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tunnel Connection',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.connectionDuration != null)
                Text(
                  'Connected ${_formatDuration(state.connectionDuration!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (state.isConnecting) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = 'Connecting...';
    } else if (state.isDisconnecting) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = 'Disconnecting...';
    } else if (state.isConnected && !state.hasError) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Connected';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Disconnected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (state.isConnecting || state.isDisconnecting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const Spacer(),
          if (state.isConnected && state.quality != TunnelConnectionQuality.unknown)
            _buildQualityIndicator(context, state.quality),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(BuildContext context, TunnelConnectionQuality quality) {
    Color qualityColor;
    switch (quality) {
      case TunnelConnectionQuality.excellent:
        qualityColor = Colors.green;
        break;
      case TunnelConnectionQuality.good:
        qualityColor = Colors.lightGreen;
        break;
      case TunnelConnectionQuality.fair:
        qualityColor = Colors.orange;
        break;
      case TunnelConnectionQuality.poor:
        qualityColor = Colors.red;
        break;
      case TunnelConnectionQuality.unknown:
        qualityColor = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: qualityColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          quality.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: qualityColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        if (state.isConnected) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: state.isDisconnecting ? null : onTest,
              icon: const Icon(Icons.network_check, size: 18),
              label: const Text('Test'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: state.isDisconnecting ? null : onDisconnect,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: state.isConnecting ? null : onConnect,
              icon: state.isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(state.isConnecting ? 'Connecting...' : 'Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

