/// Tunnel Metrics Widget
/// Compact widget for displaying tunnel metrics inline
library;

import 'package:flutter/material.dart';
import 'dart:async';

import '../services/tunnel/metrics_collector.dart';
import '../services/tunnel/connection_quality_calculator.dart';
import '../services/tunnel/interfaces/tunnel_health_metrics.dart';
import '../services/tunnel/interfaces/tunnel_models.dart';

/// Compact tunnel metrics widget for inline display
class TunnelMetricsWidget extends StatefulWidget {
  final MetricsCollector metricsCollector;
  final ConnectionQualityCalculator? qualityCalculator;
  final bool showDetails;

  const TunnelMetricsWidget({
    super.key,
    required this.metricsCollector,
    this.qualityCalculator,
    this.showDetails = false,
  });

  @override
  State<TunnelMetricsWidget> createState() => _TunnelMetricsWidgetState();
}

class _TunnelMetricsWidgetState extends State<TunnelMetricsWidget> {
  Timer? _refreshTimer;
  TunnelMetrics? _currentMetrics;
  ConnectionQuality _currentQuality = ConnectionQuality.excellent;

  @override
  void initState() {
    super.initState();
    _refreshMetrics();
    _startAutoRefresh();
    _listenToQualityChanges();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshMetrics() {
    if (mounted) {
      setState(() {
        _currentMetrics = widget.metricsCollector.getMetrics();
        _currentQuality = widget.qualityCalculator?.currentQuality ??
            widget.metricsCollector.currentQuality;
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMetrics();
    });
  }

  void _listenToQualityChanges() {
    widget.qualityCalculator?.qualityStream.listen((quality) {
      if (mounted) {
        setState(() {
          _currentQuality = quality;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMetrics == null) {
      return const SizedBox.shrink();
    }

    if (widget.showDetails) {
      return _buildDetailedView();
    } else {
      return _buildCompactView();
    }
  }

  /// Build compact view
  Widget _buildCompactView() {
    final qualityColor = _getQualityColor(_currentQuality);
    final qualityIcon = _getQualityIcon(_currentQuality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: qualityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: qualityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(qualityIcon, size: 16, color: qualityColor),
          const SizedBox(width: 8),
          Text(
            _getQualityText(_currentQuality),
            style: TextStyle(
              color: qualityColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_currentMetrics!.averageLatency.inMilliseconds}ms',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            '${(_currentMetrics!.successRate * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build detailed view
  Widget _buildDetailedView() {
    final qualityColor = _getQualityColor(_currentQuality);
    final successRate = _currentMetrics!.successRate * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getQualityIcon(_currentQuality),
                    size: 20, color: qualityColor),
                const SizedBox(width: 8),
                Text(
                  'Connection: ${_getQualityText(_currentQuality)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: qualityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMetricRow('Latency',
                '${_currentMetrics!.averageLatency.inMilliseconds}ms'),
            _buildMetricRow(
                'Success Rate', '${successRate.toStringAsFixed(1)}%'),
            _buildMetricRow('Requests', '${_currentMetrics!.totalRequests}'),
            _buildMetricRow(
                'Uptime', _formatDuration(_currentMetrics!.totalUptime)),
          ],
        ),
      ),
    );
  }

  /// Build metric row
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Get quality color
  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.lightGreen;
      case ConnectionQuality.fair:
        return Colors.orange;
      case ConnectionQuality.poor:
        return Colors.red;
    }
  }

  /// Get quality text
  String _getQualityText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.fair:
        return 'Fair';
      case ConnectionQuality.poor:
        return 'Poor';
    }
  }

  /// Get quality icon
  IconData _getQualityIcon(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Icons.signal_cellular_alt;
      case ConnectionQuality.good:
        return Icons.signal_cellular_4_bar;
      case ConnectionQuality.fair:
        return Icons.signal_cellular_alt_2_bar;
      case ConnectionQuality.poor:
        return Icons.signal_cellular_alt_1_bar;
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// Connection quality indicator badge
class ConnectionQualityBadge extends StatelessWidget {
  final ConnectionQuality quality;
  final bool showLabel;

  const ConnectionQualityBadge({
    super.key,
    required this.quality,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor(quality);
    final icon = _getQualityIcon(quality);
    final text = _getQualityText(quality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.lightGreen;
      case ConnectionQuality.fair:
        return Colors.orange;
      case ConnectionQuality.poor:
        return Colors.red;
    }
  }

  String _getQualityText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.fair:
        return 'Fair';
      case ConnectionQuality.poor:
        return 'Poor';
    }
  }

  IconData _getQualityIcon(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Icons.signal_cellular_alt;
      case ConnectionQuality.good:
        return Icons.signal_cellular_4_bar;
      case ConnectionQuality.fair:
        return Icons.signal_cellular_alt_2_bar;
      case ConnectionQuality.poor:
        return Icons.signal_cellular_alt_1_bar;
    }
  }
}
