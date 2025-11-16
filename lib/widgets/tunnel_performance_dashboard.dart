/// Tunnel Performance Dashboard Widget
/// Displays real-time tunnel connection metrics and performance indicators
library;

import 'package:flutter/material.dart';
import 'dart:async';

import '../services/tunnel/metrics_collector.dart';
import '../services/tunnel/connection_quality_calculator.dart';
import '../services/tunnel/interfaces/tunnel_health_metrics.dart';
import '../services/tunnel/interfaces/tunnel_models.dart';

/// Performance dashboard widget for tunnel metrics
class TunnelPerformanceDashboard extends StatefulWidget {
  final MetricsCollector metricsCollector;
  final ConnectionQualityCalculator? qualityCalculator;

  const TunnelPerformanceDashboard({
    super.key,
    required this.metricsCollector,
    this.qualityCalculator,
  });

  @override
  State<TunnelPerformanceDashboard> createState() =>
      _TunnelPerformanceDashboardState();
}

class _TunnelPerformanceDashboardState
    extends State<TunnelPerformanceDashboard> {
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
    setState(() {
      _currentMetrics = widget.metricsCollector.getMetrics();
      _currentQuality = widget.qualityCalculator?.currentQuality ??
          widget.metricsCollector.currentQuality;
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnel Performance'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMetrics,
            tooltip: 'Refresh metrics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionQualityCard(),
            const SizedBox(height: 16),
            _buildRequestMetricsCard(),
            const SizedBox(height: 16),
            _buildLatencyMetricsCard(),
            const SizedBox(height: 16),
            _buildConnectionStatsCard(),
            const SizedBox(height: 16),
            _buildQueueStatusCard(),
          ],
        ),
      ),
    );
  }

  /// Build connection quality indicator card
  Widget _buildConnectionQualityCard() {
    final qualityColor = _getQualityColor(_currentQuality);
    final qualityText = _getQualityText(_currentQuality);
    final qualityIcon = _getQualityIcon(_currentQuality);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: qualityColor),
                const SizedBox(width: 8),
                Text(
                  'Connection Quality',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(qualityIcon, size: 48, color: qualityColor),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qualityText,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: qualityColor,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      _getQualityDescription(_currentQuality),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQualityIndicatorBar(),
          ],
        ),
      ),
    );
  }

  /// Build quality indicator progress bar
  Widget _buildQualityIndicatorBar() {
    final qualityScore = _getQualityScore(_currentQuality);
    final qualityColor = _getQualityColor(_currentQuality);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quality Score',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '$qualityScore/100',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: qualityScore / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
          minHeight: 8,
        ),
      ],
    );
  }

  /// Build request metrics card
  Widget _buildRequestMetricsCard() {
    if (_currentMetrics == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final successRate = _currentMetrics!.successRate * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined),
                const SizedBox(width: 8),
                Text(
                  'Request Metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  'Total',
                  '${_currentMetrics!.totalRequests}',
                  Icons.all_inbox,
                  Colors.blue,
                ),
                _buildMetricItem(
                  'Success',
                  '${_currentMetrics!.successfulRequests}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildMetricItem(
                  'Failed',
                  '${_currentMetrics!.failedRequests}',
                  Icons.error,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSuccessRateBar(successRate),
          ],
        ),
      ),
    );
  }

  /// Build success rate progress bar
  Widget _buildSuccessRateBar(double successRate) {
    final color = successRate >= 99
        ? Colors.green
        : successRate >= 95
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Success Rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${successRate.toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: successRate / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  /// Build latency metrics card
  Widget _buildLatencyMetricsCard() {
    if (_currentMetrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 8),
                Text(
                  'Latency Metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLatencyItem(
                  'Average',
                  _currentMetrics!.averageLatency,
                  Colors.blue,
                ),
                _buildLatencyItem(
                  'P95',
                  _currentMetrics!.p95Latency,
                  Colors.orange,
                ),
                _buildLatencyItem(
                  'P99',
                  _currentMetrics!.p99Latency,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build connection stats card
  Widget _buildConnectionStatsCard() {
    if (_currentMetrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link),
                const SizedBox(width: 8),
                Text(
                  'Connection Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Uptime', _formatDuration(_currentMetrics!.totalUptime)),
            const SizedBox(height: 8),
            _buildStatRow(
                'Reconnections', '${_currentMetrics!.reconnectionCount}'),
            const SizedBox(height: 8),
            _buildStatRow(
              'Packet Loss',
              '${(widget.metricsCollector.getPacketLoss() * 100).toStringAsFixed(2)}%',
            ),
          ],
        ),
      ),
    );
  }

  /// Build queue status card
  Widget _buildQueueStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.queue),
                const SizedBox(width: 8),
                Text(
                  'Queue Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Queued Requests', '0'), // Will be connected to actual queue
            const SizedBox(height: 8),
            _buildStatRow('Queue Capacity', '100'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.0, // Will be connected to actual queue fill percentage
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  /// Build a metric item widget
  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Build a latency item widget
  Widget _buildLatencyItem(String label, Duration latency, Color color) {
    return Column(
      children: [
        Text(
          '${latency.inMilliseconds}ms',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Build a stat row widget
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
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

  /// Get quality description
  String _getQualityDescription(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Low latency, no packet loss';
      case ConnectionQuality.good:
        return 'Good performance';
      case ConnectionQuality.fair:
        return 'Acceptable performance';
      case ConnectionQuality.poor:
        return 'High latency or packet loss';
    }
  }

  /// Get quality score
  int _getQualityScore(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 95;
      case ConnectionQuality.good:
        return 75;
      case ConnectionQuality.fair:
        return 50;
      case ConnectionQuality.poor:
        return 25;
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
