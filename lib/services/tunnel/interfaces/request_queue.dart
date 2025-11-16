/// Request Queue Interface
/// Priority-based request queue with persistence support
library;

import 'tunnel_models.dart';

// RequestPriority is defined in tunnel_models.dart and exported from there

/// Backpressure signal
class BackpressureSignal {
  final double queueFillPercentage;
  final bool shouldThrottle;
  final String? message;

  const BackpressureSignal({
    required this.queueFillPercentage,
    required this.shouldThrottle,
    this.message,
  });
}

/// Abstract interface for request queue
abstract class RequestQueue {
  /// Enqueue a request with priority
  Future<void> enqueue(
    TunnelRequest request, {
    RequestPriority priority = RequestPriority.normal,
  });

  /// Dequeue next request
  Future<TunnelRequest?> dequeue();

  /// Clear all requests
  void clear();

  /// Get queue size
  int get size;

  /// Check if queue is full
  bool get isFull;

  /// Check if queue is empty
  bool get isEmpty;

  /// Get fill percentage (0.0 to 1.0)
  double get fillPercentage;

  /// Persist high-priority requests to disk
  Future<void> persistHighPriorityRequests();

  /// Restore persisted requests
  Future<void> restorePersistedRequests();

  /// Stream of backpressure signals
  Stream<BackpressureSignal> get backpressureStream;
}
