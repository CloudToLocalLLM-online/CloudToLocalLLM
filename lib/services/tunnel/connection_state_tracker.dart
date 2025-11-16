/// Connection State Tracker
/// Tracks connection lifecycle events and state transitions
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'interfaces/tunnel_models.dart';

/// Connection state tracker for managing connection lifecycle
class ConnectionStateTracker extends ChangeNotifier {
  TunnelConnection? _connection;
  final int maxEventHistory;
  final StreamController<ConnectionEvent> _eventStreamController =
      StreamController<ConnectionEvent>.broadcast();

  ConnectionStateTracker({
    this.maxEventHistory = 100,
  });

  /// Get current connection
  TunnelConnection? get connection => _connection;

  /// Get current connection state
  TunnelConnectionState get state =>
      _connection?.state ?? TunnelConnectionState.disconnected;

  /// Alias for state property
  TunnelConnectionState get currentState => state;

  /// Get event stream for listening to state changes
  Stream<ConnectionEvent> get eventStream => _eventStreamController.stream;

  /// Get event history
  List<ConnectionEvent> get eventHistory => _connection?.eventHistory ?? [];

  /// Get last event
  ConnectionEvent? get lastEvent =>
      eventHistory.isNotEmpty ? eventHistory.last : null;

  /// Get reconnect attempts
  int get reconnectAttempts => _connection?.reconnectAttempts ?? 0;

  /// Get last activity time
  DateTime? get lastActivityAt => _connection?.lastActivityAt;

  /// Get connection uptime
  Duration get uptime {
    if (_connection == null ||
        _connection!.state == TunnelConnectionState.disconnected) {
      return Duration.zero;
    }
    return DateTime.now().difference(_connection!.connectedAt);
  }

  /// Initialize connection tracking
  ///
  /// Creates a new connection object and sets initial state
  void initializeConnection({
    required String id,
    required String userId,
    required String serverUrl,
  }) {
    _connection = TunnelConnection(
      id: id,
      userId: userId,
      serverUrl: serverUrl,
      connectedAt: DateTime.now(),
      state: TunnelConnectionState.connecting,
    );

    _addEvent(ConnectionEvent(
      type: ConnectionEventType.connected,
      message: 'Connection initialized',
      metadata: {
        'id': id,
        'serverUrl': serverUrl,
      },
    ));

    notifyListeners();
  }

  /// Update connection state
  ///
  /// Transitions to a new state and records the event
  void updateState(
    TunnelConnectionState newState, {
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    if (_connection == null) {
      debugPrint('[ConnectionStateTracker] Cannot update state: no connection');
      return;
    }

    final oldState = _connection!.state;
    _connection!.state = newState;
    _connection!.lastActivityAt = DateTime.now();

    final event = ConnectionEvent(
      type: _stateToEventType(newState),
      message: message ?? _getDefaultStateMessage(oldState, newState),
      metadata: metadata,
    );

    _addEvent(event);

    debugPrint(
        '[ConnectionStateTracker] State transition: ${oldState.name} -> ${newState.name}');

    notifyListeners();
  }

  /// Record connection event
  ///
  /// Adds an event to the history without changing state
  void recordEvent(ConnectionEvent event) {
    _addEvent(event);
    notifyListeners();
  }

  /// Increment reconnect attempts
  void incrementReconnectAttempts() {
    if (_connection == null) return;

    _connection!.reconnectAttempts++;
    _connection!.lastActivityAt = DateTime.now();

    _addEvent(ConnectionEvent(
      type: ConnectionEventType.reconnecting,
      message: 'Reconnection attempt ${_connection!.reconnectAttempts}',
      metadata: {
        'attempt': _connection!.reconnectAttempts,
      },
    ));

    notifyListeners();
  }

  /// Reset reconnect attempts
  ///
  /// Called after successful reconnection
  void resetReconnectAttempts() {
    if (_connection == null) return;

    final previousAttempts = _connection!.reconnectAttempts;
    _connection!.reconnectAttempts = 0;

    if (previousAttempts > 0) {
      _addEvent(ConnectionEvent(
        type: ConnectionEventType.reconnected,
        message: 'Reconnected successfully after $previousAttempts attempts',
        metadata: {
          'previousAttempts': previousAttempts,
        },
      ));
    }

    notifyListeners();
  }

  /// Record health check
  void recordHealthCheck({
    required bool healthy,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    _addEvent(ConnectionEvent(
      type: ConnectionEventType.healthCheck,
      message:
          message ?? (healthy ? 'Health check passed' : 'Health check failed'),
      metadata: {
        'healthy': healthy,
        ...?metadata,
      },
    ));

    notifyListeners();
  }

  /// Record configuration change
  void recordConfigChange({
    required String configKey,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    _addEvent(ConnectionEvent(
      type: ConnectionEventType.configChanged,
      message: 'Configuration changed: $configKey',
      metadata: {
        'configKey': configKey,
        'oldValue': oldValue,
        'newValue': newValue,
      },
    ));

    notifyListeners();
  }

  /// Record error
  void recordError(TunnelError error) {
    _addEvent(ConnectionEvent(
      type: ConnectionEventType.error,
      message: error.userMessage,
      metadata: {
        'errorCode': error.code,
        'errorCategory': error.category.name,
        'errorMessage': error.message,
      },
    ));

    notifyListeners();
  }

  /// Clear connection
  ///
  /// Resets all connection state and history
  void clearConnection() {
    if (_connection != null) {
      _addEvent(ConnectionEvent(
        type: ConnectionEventType.disconnected,
        message: 'Connection cleared',
      ));
    }

    _connection = null;
    notifyListeners();
  }

  /// Get events by type
  List<ConnectionEvent> getEventsByType(ConnectionEventType type) {
    return eventHistory.where((e) => e.type == type).toList();
  }

  /// Get events in time window
  List<ConnectionEvent> getEventsInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return eventHistory.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  /// Get error events
  List<ConnectionEvent> getErrorEvents() {
    return getEventsByType(ConnectionEventType.error);
  }

  /// Get reconnection events
  List<ConnectionEvent> getReconnectionEvents() {
    return eventHistory
        .where((e) =>
            e.type == ConnectionEventType.reconnecting ||
            e.type == ConnectionEventType.reconnected)
        .toList();
  }

  /// Add event to history
  void _addEvent(ConnectionEvent event) {
    if (_connection != null) {
      _connection!.addEvent(event);

      // Trim history if needed
      while (_connection!.eventHistory.length > maxEventHistory) {
        _connection!.eventHistory.removeAt(0);
      }
    }

    // Emit event to stream
    _eventStreamController.add(event);
  }

  /// Convert state to event type
  ConnectionEventType _stateToEventType(TunnelConnectionState state) {
    switch (state) {
      case TunnelConnectionState.connected:
        return ConnectionEventType.connected;
      case TunnelConnectionState.disconnected:
        return ConnectionEventType.disconnected;
      case TunnelConnectionState.reconnecting:
        return ConnectionEventType.reconnecting;
      case TunnelConnectionState.error:
        return ConnectionEventType.error;
      case TunnelConnectionState.connecting:
        return ConnectionEventType.connected;
    }
  }

  /// Get default message for state transition
  String _getDefaultStateMessage(
    TunnelConnectionState oldState,
    TunnelConnectionState newState,
  ) {
    switch (newState) {
      case TunnelConnectionState.connecting:
        return 'Connecting to server...';
      case TunnelConnectionState.connected:
        return oldState == TunnelConnectionState.reconnecting
            ? 'Reconnected successfully'
            : 'Connected successfully';
      case TunnelConnectionState.disconnected:
        return 'Disconnected from server';
      case TunnelConnectionState.reconnecting:
        return 'Connection lost, attempting to reconnect...';
      case TunnelConnectionState.error:
        return 'Connection error occurred';
    }
  }

  /// Export connection state to JSON
  Map<String, dynamic>? toJson() {
    return _connection?.toJson();
  }

  /// Restore connection state from JSON
  void fromJson(Map<String, dynamic> json) {
    _connection = TunnelConnection.fromJson(json);
    notifyListeners();
  }

  @override
  void dispose() {
    _eventStreamController.close();
    super.dispose();
  }
}
