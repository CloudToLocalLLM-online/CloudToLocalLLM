/// Request Timeout Handler
/// Tracks and handles request timeouts
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'interfaces/tunnel_models.dart';
import 'persistent_request_queue.dart';

/// Timeout event
class TimeoutEvent {
  final TunnelRequest request;
  final DateTime timeoutAt;
  final DateTime detectedAt;
  final Duration queuedDuration;

  TimeoutEvent({
    required this.request,
    required this.timeoutAt,
    DateTime? detectedAt,
    required this.queuedDuration,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'requestId': request.id,
      'timeoutAt': timeoutAt.toIso8601String(),
      'detectedAt': detectedAt.toIso8601String(),
      'queuedDuration': queuedDuration.inMilliseconds,
    };
  }
}

/// Request timeout handler
/// Monitors queue for timed out requests and generates timeout errors
class RequestTimeoutHandler extends ChangeNotifier {
  final PersistentRequestQueue queue;
  final Duration checkInterval;

  Timer? _checkTimer;
  final List<TimeoutEvent> _timeoutHistory = [];
  final int _maxHistorySize = 100;

  // Stream controller for timeout events
  final StreamController<TimeoutEvent> _timeoutController =
      StreamController<TimeoutEvent>.broadcast();

  // Statistics
  int _totalTimeouts = 0;
  DateTime? _lastTimeoutCheck;

  RequestTimeoutHandler({
    required this.queue,
    this.checkInterval = const Duration(seconds: 5),
  });

  /// Stream of timeout events
  Stream<TimeoutEvent> get timeoutStream => _timeoutController.stream;

  /// Get total timeout count
  int get totalTimeouts => _totalTimeouts;

  /// Get timeout history
  List<TimeoutEvent> get timeoutHistory => List.unmodifiable(_timeoutHistory);

  /// Get last timeout check time
  DateTime? get lastTimeoutCheck => _lastTimeoutCheck;

  /// Start monitoring for timeouts
  void startMonitoring() {
    stopMonitoring(); // Stop any existing timer

    _checkTimer = Timer.periodic(checkInterval, (_) {
      _checkForTimeouts();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Check for timed out requests
  Future<List<TimeoutEvent>> _checkForTimeouts() async {
    _lastTimeoutCheck = DateTime.now();
    final timedOutRequests = await queue.removeTimedOutRequests();
    final events = <TimeoutEvent>[];

    for (final request in timedOutRequests) {
      final event = TimeoutEvent(
        request: request,
        timeoutAt: request.createdAt.add(request.timeout),
        queuedDuration: DateTime.now().difference(request.createdAt),
      );

      events.add(event);
      _recordTimeout(event);
    }

    if (events.isNotEmpty) {
      notifyListeners();
    }

    return events;
  }

  /// Manually check for timeouts (can be called on-demand)
  Future<List<TimeoutEvent>> checkTimeouts() async {
    return await _checkForTimeouts();
  }

  /// Record a timeout event
  void _recordTimeout(TimeoutEvent event) {
    _totalTimeouts++;
    _timeoutHistory.add(event);

    // Trim history
    if (_timeoutHistory.length > _maxHistorySize) {
      _timeoutHistory.removeAt(0);
    }

    // Emit event
    _timeoutController.add(event);
  }

  /// Generate timeout error for a request
  TunnelError generateTimeoutError(TunnelRequest request) {
    return TunnelError(
      category: TunnelErrorCategory.network,
      code: TunnelErrorCodes.requestTimeout,
      message: 'Request ${request.id} timed out after ${request.timeout}',
      userMessage: 'Request timed out. Please try again.',
      suggestion: 'Check your network connection and try again',
      context: {
        'requestId': request.id,
        'timeout': request.timeout.inMilliseconds,
        'priority': request.priority.name,
        'createdAt': request.createdAt.toIso8601String(),
      },
    );
  }

  /// Get timeout statistics
  Map<String, dynamic> getStatistics() {
    final recentTimeouts = _timeoutHistory
        .where((e) =>
            DateTime.now().difference(e.detectedAt) < const Duration(hours: 1))
        .length;

    final avgQueuedDuration = _timeoutHistory.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds: _timeoutHistory
                    .map((e) => e.queuedDuration.inMilliseconds)
                    .reduce((a, b) => a + b) ~/
                _timeoutHistory.length,
          );

    return {
      'totalTimeouts': _totalTimeouts,
      'recentTimeouts': recentTimeouts,
      'historySize': _timeoutHistory.length,
      'averageQueuedDuration': avgQueuedDuration.inMilliseconds,
      'lastCheck': _lastTimeoutCheck?.toIso8601String(),
      'isMonitoring': _checkTimer?.isActive ?? false,
    };
  }

  /// Clear timeout history
  void clearHistory() {
    _timeoutHistory.clear();
    notifyListeners();
  }

  /// Reset statistics
  void resetStatistics() {
    _totalTimeouts = 0;
    _timeoutHistory.clear();
    _lastTimeoutCheck = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _timeoutController.close();
    super.dispose();
  }
}
