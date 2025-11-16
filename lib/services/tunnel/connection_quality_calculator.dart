/// Connection Quality Calculator
/// Calculates and tracks connection quality in real-time
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'interfaces/tunnel_health_metrics.dart';

/// Connection quality thresholds
class QualityThresholds {
  // Latency thresholds in milliseconds
  static const double excellentLatency = 50.0;
  static const double goodLatency = 100.0;
  static const double fairLatency = 200.0;

  // Packet loss thresholds (as percentage)
  static const double excellentPacketLoss = 0.01; // 1%
  static const double goodPacketLoss = 0.03; // 3%
  static const double fairPacketLoss = 0.05; // 5%
}

/// Quality measurement data point
class QualityMeasurement {
  final DateTime timestamp;
  final double latency;
  final bool success;

  QualityMeasurement({
    required this.timestamp,
    required this.latency,
    required this.success,
  });
}

/// Connection quality calculator with real-time updates
class ConnectionQualityCalculator {
  /// Sample size for quality calculation
  static const int sampleSize = 100;

  /// Update interval for quality recalculation
  static const Duration updateInterval = Duration(seconds: 5);

  /// Recent measurements for quality calculation
  final Queue<QualityMeasurement> _measurements = Queue<QualityMeasurement>();

  /// Current connection quality
  ConnectionQuality _currentQuality = ConnectionQuality.excellent;

  /// Stream controller for quality changes
  final StreamController<ConnectionQuality> _qualityController =
      StreamController<ConnectionQuality>.broadcast();

  /// Timer for periodic quality updates
  Timer? _updateTimer;

  /// Last quality update time
  DateTime? _lastUpdateTime;

  /// Constructor
  ConnectionQualityCalculator() {
    _startPeriodicUpdates();
  }

  /// Get current connection quality
  ConnectionQuality get currentQuality => _currentQuality;

  /// Stream of quality changes
  Stream<ConnectionQuality> get qualityStream => _qualityController.stream;

  /// Add a measurement
  void addMeasurement({
    required double latency,
    required bool success,
  }) {
    final measurement = QualityMeasurement(
      timestamp: DateTime.now(),
      latency: latency,
      success: success,
    );

    _measurements.addLast(measurement);

    // Maintain sample size
    if (_measurements.length > sampleSize) {
      _measurements.removeFirst();
    }

    // Update quality if enough time has passed
    final now = DateTime.now();
    if (_lastUpdateTime == null ||
        now.difference(_lastUpdateTime!) >= updateInterval) {
      _updateQuality();
      _lastUpdateTime = now;
    }
  }

  /// Calculate quality from current measurements
  ConnectionQuality calculateQuality() {
    if (_measurements.isEmpty) {
      return ConnectionQuality.excellent;
    }

    // Calculate average latency
    final avgLatency = _calculateAverageLatency();

    // Calculate packet loss
    final packetLoss = _calculatePacketLoss();

    // Determine quality based on thresholds
    return _determineQuality(avgLatency, packetLoss);
  }

  /// Update quality and notify listeners if changed
  void _updateQuality() {
    final newQuality = calculateQuality();

    if (newQuality != _currentQuality) {
      _currentQuality = newQuality;
      _qualityController.add(_currentQuality);
    }
  }

  /// Calculate average latency from measurements
  double _calculateAverageLatency() {
    if (_measurements.isEmpty) return 0.0;

    final totalLatency = _measurements.fold<double>(
      0.0,
      (sum, m) => sum + m.latency,
    );

    return totalLatency / _measurements.length;
  }

  /// Calculate packet loss percentage
  double _calculatePacketLoss() {
    if (_measurements.isEmpty) return 0.0;

    final failedCount = _measurements.where((m) => !m.success).length;
    return failedCount / _measurements.length;
  }

  /// Determine quality based on latency and packet loss
  ConnectionQuality _determineQuality(double latency, double packetLoss) {
    // Use the existing calculation from TunnelHealthMetrics
    return TunnelHealthMetrics.calculateQuality(
      latency: latency,
      packetLoss: packetLoss,
    );
  }

  /// Get quality indicator text
  String getQualityText() {
    switch (_currentQuality) {
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

  /// Get quality indicator color (as hex string)
  String getQualityColor() {
    switch (_currentQuality) {
      case ConnectionQuality.excellent:
        return '#4CAF50'; // Green
      case ConnectionQuality.good:
        return '#8BC34A'; // Light Green
      case ConnectionQuality.fair:
        return '#FFC107'; // Amber
      case ConnectionQuality.poor:
        return '#F44336'; // Red
    }
  }

  /// Get quality score (0-100)
  int getQualityScore() {
    if (_measurements.isEmpty) return 100;

    final avgLatency = _calculateAverageLatency();
    final packetLoss = _calculatePacketLoss();

    // Calculate latency score (0-50 points)
    final latencyScore = _calculateLatencyScore(avgLatency);

    // Calculate packet loss score (0-50 points)
    final packetLossScore = _calculatePacketLossScore(packetLoss);

    return (latencyScore + packetLossScore).round();
  }

  /// Calculate latency score component
  double _calculateLatencyScore(double latency) {
    if (latency <= QualityThresholds.excellentLatency) {
      return 50.0;
    } else if (latency <= QualityThresholds.goodLatency) {
      // Linear interpolation between excellent and good
      final ratio = (latency - QualityThresholds.excellentLatency) /
          (QualityThresholds.goodLatency - QualityThresholds.excellentLatency);
      return 50.0 - (ratio * 15.0); // 50 to 35
    } else if (latency <= QualityThresholds.fairLatency) {
      // Linear interpolation between good and fair
      final ratio = (latency - QualityThresholds.goodLatency) /
          (QualityThresholds.fairLatency - QualityThresholds.goodLatency);
      return 35.0 - (ratio * 15.0); // 35 to 20
    } else {
      // Poor quality, exponential decay
      final excess = latency - QualityThresholds.fairLatency;
      return max(0.0, 20.0 - (excess / 10.0));
    }
  }

  /// Calculate packet loss score component
  double _calculatePacketLossScore(double packetLoss) {
    if (packetLoss <= QualityThresholds.excellentPacketLoss) {
      return 50.0;
    } else if (packetLoss <= QualityThresholds.goodPacketLoss) {
      // Linear interpolation between excellent and good
      final ratio = (packetLoss - QualityThresholds.excellentPacketLoss) /
          (QualityThresholds.goodPacketLoss -
              QualityThresholds.excellentPacketLoss);
      return 50.0 - (ratio * 15.0); // 50 to 35
    } else if (packetLoss <= QualityThresholds.fairPacketLoss) {
      // Linear interpolation between good and fair
      final ratio = (packetLoss - QualityThresholds.goodPacketLoss) /
          (QualityThresholds.fairPacketLoss - QualityThresholds.goodPacketLoss);
      return 35.0 - (ratio * 15.0); // 35 to 20
    } else {
      // Poor quality, exponential decay
      final excess = packetLoss - QualityThresholds.fairPacketLoss;
      return max(0.0, 20.0 - (excess * 100.0));
    }
  }

  /// Get detailed quality metrics
  Map<String, dynamic> getQualityMetrics() {
    return {
      'quality': _currentQuality.name,
      'qualityText': getQualityText(),
      'qualityColor': getQualityColor(),
      'qualityScore': getQualityScore(),
      'averageLatency': _calculateAverageLatency(),
      'packetLoss': _calculatePacketLoss(),
      'sampleSize': _measurements.length,
    };
  }

  /// Start periodic quality updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(updateInterval, (_) {
      _updateQuality();
    });
  }

  /// Stop periodic updates
  void stopUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Clear all measurements
  void clear() {
    _measurements.clear();
    _currentQuality = ConnectionQuality.excellent;
    _lastUpdateTime = null;
  }

  /// Dispose resources
  void dispose() {
    stopUpdates();
    _qualityController.close();
  }
}
