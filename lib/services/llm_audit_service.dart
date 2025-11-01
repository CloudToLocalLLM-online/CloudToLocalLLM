import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/tunnel_logger.dart';
import 'auth_service.dart';

/// LLM Audit Service
///
/// Provides comprehensive audit logging for LLM interactions including
/// request tracking, usage monitoring, security events, and performance metrics.
class LLMAuditService extends ChangeNotifier {
  final AuthService _authService;
  

  // State
  bool _isInitialized = false;
  final List<LLMAuditEvent> _auditLog = [];
  final Map<String, LLMUsageStats> _usageStats = {};

  // Configuration
  static const int _maxAuditLogSize = 1000;
  static const String _prefAuditLog = 'llm_audit_log';
  static const String _prefUsageStats = 'llm_usage_stats';

  LLMAuditService({required AuthService authService})
    : _authService = authService;

  // Getters
  bool get isInitialized => _isInitialized;
  List<LLMAuditEvent> get auditLog => List.unmodifiable(_auditLog);
  Map<String, LLMUsageStats> get usageStats => Map.unmodifiable(_usageStats);

  /// Initialize the audit service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[llm_audit_service] Initializing LLM Audit Service');

      // Load persisted audit data
      await _loadAuditData();

      _isInitialized = true;
      debugPrint('[llm_audit_service] LLM Audit Service initialized successfully');
    } catch (e) {
      _logger.logTunnelError(
        'AUDIT_INIT_FAILED',
        'Failed to initialize audit service',
        error: e,
      );
      rethrow;
    }
  }

  /// Log an LLM interaction
  Future<void> logLLMInteraction({
    required String providerId,
    required String modelId,
    required String requestType,
    required int requestSize,
    int? responseSize,
    int? responseTime,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';

    final event = LLMAuditEvent(
      id: _generateEventId(),
      timestamp: DateTime.now(),
      userId: userId,
      providerId: providerId,
      modelId: modelId,
      eventType: LLMAuditEventType.interaction,
      requestType: requestType,
      requestSize: requestSize,
      responseSize: responseSize,
      responseTime: responseTime,
      success: success,
      errorMessage: errorMessage,
      metadata: metadata ?? {},
    );

    await _addAuditEvent(event);
    await _updateUsageStats(event);

    _logger.info(
      'Logged LLM interaction',
      context: {
        'providerId': providerId,
        'modelId': modelId,
        'requestType': requestType,
        'success': success,
        'responseTime': responseTime,
      },
    );
  }

  /// Log a security event
  Future<void> logSecurityEvent({
    required String eventType,
    required String description,
    String? providerId,
    String? modelId,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';

    final event = LLMAuditEvent(
      id: _generateEventId(),
      timestamp: DateTime.now(),
      userId: userId,
      providerId: providerId,
      modelId: modelId,
      eventType: LLMAuditEventType.security,
      requestType: eventType,
      description: description,
      metadata: metadata ?? {},
    );

    await _addAuditEvent(event);

    _logger.logTunnelError(
      'SECURITY_EVENT',
      description,
      context: {
        'eventType': eventType,
        'providerId': providerId,
        'modelId': modelId,
        'userId': userId,
      },
    );
  }

  /// Log a provider event
  Future<void> logProviderEvent({
    required String providerId,
    required String eventType,
    required String description,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';

    final event = LLMAuditEvent(
      id: _generateEventId(),
      timestamp: DateTime.now(),
      userId: userId,
      providerId: providerId,
      eventType: LLMAuditEventType.provider,
      requestType: eventType,
      description: description,
      success: success,
      errorMessage: errorMessage,
      metadata: metadata ?? {},
    );

    await _addAuditEvent(event);

    _logger.info(
      'Logged provider event',
      context: {
        'providerId': providerId,
        'eventType': eventType,
        'success': success,
      },
    );
  }

  /// Get usage statistics for a specific period
  LLMUsageStats getUsageStats({
    String? providerId,
    String? modelId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filteredEvents = _auditLog.where((event) {
      if (event.eventType != LLMAuditEventType.interaction) return false;
      if (providerId != null && event.providerId != providerId) return false;
      if (modelId != null && event.modelId != modelId) return false;
      if (startDate != null && event.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && event.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();

    return _calculateUsageStats(filteredEvents);
  }

  /// Get recent audit events
  List<LLMAuditEvent> getRecentEvents({
    int limit = 50,
    LLMAuditEventType? eventType,
    String? providerId,
  }) {
    var events = _auditLog.where((event) {
      if (eventType != null && event.eventType != eventType) return false;
      if (providerId != null && event.providerId != providerId) return false;
      return true;
    }).toList();

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }

  /// Clear audit log
  Future<void> clearAuditLog() async {
    _auditLog.clear();
    _usageStats.clear();
    await _saveAuditData();
    notifyListeners();

    debugPrint('[llm_audit_service] Cleared audit log');
  }

  /// Export audit log
  String exportAuditLog({
    DateTime? startDate,
    DateTime? endDate,
    LLMAuditEventType? eventType,
  }) {
    var events = _auditLog.where((event) {
      if (startDate != null && event.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && event.timestamp.isAfter(endDate)) return false;
      if (eventType != null && event.eventType != eventType) return false;
      return true;
    }).toList();

    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return json.encode({
      'exportDate': DateTime.now().toIso8601String(),
      'eventCount': events.length,
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  // Private methods
  Future<void> _addAuditEvent(LLMAuditEvent event) async {
    _auditLog.add(event);

    // Maintain log size limit
    if (_auditLog.length > _maxAuditLogSize) {
      _auditLog.removeRange(0, _auditLog.length - _maxAuditLogSize);
    }

    await _saveAuditData();
    notifyListeners();
  }

  Future<void> _updateUsageStats(LLMAuditEvent event) async {
    final key = '${event.providerId}:${event.modelId}';
    final stats =
        _usageStats[key] ??
        LLMUsageStats(providerId: event.providerId!, modelId: event.modelId!);

    stats.totalRequests++;
    if (event.success) {
      stats.successfulRequests++;
    } else {
      stats.failedRequests++;
    }

    if (event.requestSize != null) {
      stats.totalInputTokens += event.requestSize!;
    }

    if (event.responseSize != null) {
      stats.totalOutputTokens += event.responseSize!;
    }

    if (event.responseTime != null) {
      stats.totalResponseTime += event.responseTime!;
      stats.averageResponseTime =
          stats.totalResponseTime / stats.successfulRequests;
    }

    stats.lastUsed = event.timestamp;
    _usageStats[key] = stats;
  }

  LLMUsageStats _calculateUsageStats(List<LLMAuditEvent> events) {
    if (events.isEmpty) {
      return LLMUsageStats(providerId: '', modelId: '');
    }

    final stats = LLMUsageStats(
      providerId: events.first.providerId ?? '',
      modelId: events.first.modelId ?? '',
    );

    for (final event in events) {
      stats.totalRequests++;
      if (event.success) {
        stats.successfulRequests++;
      } else {
        stats.failedRequests++;
      }

      if (event.requestSize != null) {
        stats.totalInputTokens += event.requestSize!;
      }

      if (event.responseSize != null) {
        stats.totalOutputTokens += event.responseSize!;
      }

      if (event.responseTime != null) {
        stats.totalResponseTime += event.responseTime!;
      }
    }

    if (stats.successfulRequests > 0) {
      stats.averageResponseTime =
          stats.totalResponseTime / stats.successfulRequests;
    }

    return stats;
  }

  Future<void> _loadAuditData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load audit log
      final auditLogJson = prefs.getString(_prefAuditLog);
      if (auditLogJson != null) {
        final data = json.decode(auditLogJson) as List<dynamic>;
        _auditLog.clear();
        _auditLog.addAll(
          data.map((e) => LLMAuditEvent.fromJson(e as Map<String, dynamic>)),
        );
      }

      // Load usage stats
      final usageStatsJson = prefs.getString(_prefUsageStats);
      if (usageStatsJson != null) {
        final data = json.decode(usageStatsJson) as Map<String, dynamic>;
        _usageStats.clear();
        data.forEach((key, value) {
          _usageStats[key] = LLMUsageStats.fromJson(
            value as Map<String, dynamic>,
          );
        });
      }
    } catch (e) {
      _logger.logTunnelError(
        'LOAD_AUDIT_DATA_FAILED',
        'Failed to load audit data',
        error: e,
      );
    }
  }

  Future<void> _saveAuditData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save audit log
      final auditLogJson = json.encode(
        _auditLog.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_prefAuditLog, auditLogJson);

      // Save usage stats
      final usageStatsJson = json.encode(
        _usageStats.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_prefUsageStats, usageStatsJson);
    } catch (e) {
      _logger.logTunnelError(
        'SAVE_AUDIT_DATA_FAILED',
        'Failed to save audit data',
        error: e,
      );
    }
  }

  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_auditLog.length}';
  }

  @override
  void dispose() {
    _saveAuditData();
    super.dispose();
  }
}

/// LLM Audit Event
class LLMAuditEvent {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String? providerId;
  final String? modelId;
  final LLMAuditEventType eventType;
  final String requestType;
  final String? description;
  final int? requestSize;
  final int? responseSize;
  final int? responseTime;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  const LLMAuditEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    this.providerId,
    this.modelId,
    required this.eventType,
    required this.requestType,
    this.description,
    this.requestSize,
    this.responseSize,
    this.responseTime,
    this.success = true,
    this.errorMessage,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'providerId': providerId,
    'modelId': modelId,
    'eventType': eventType.name,
    'requestType': requestType,
    'description': description,
    'requestSize': requestSize,
    'responseSize': responseSize,
    'responseTime': responseTime,
    'success': success,
    'errorMessage': errorMessage,
    'metadata': metadata,
  };

  factory LLMAuditEvent.fromJson(Map<String, dynamic> json) {
    return LLMAuditEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      providerId: json['providerId'] as String?,
      modelId: json['modelId'] as String?,
      eventType: LLMAuditEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => LLMAuditEventType.interaction,
      ),
      requestType: json['requestType'] as String,
      description: json['description'] as String?,
      requestSize: json['requestSize'] as int?,
      responseSize: json['responseSize'] as int?,
      responseTime: json['responseTime'] as int?,
      success: json['success'] as bool? ?? true,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// LLM Usage Statistics
class LLMUsageStats {
  final String providerId;
  final String modelId;
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int totalInputTokens = 0;
  int totalOutputTokens = 0;
  int totalResponseTime = 0;
  double averageResponseTime = 0.0;
  DateTime? lastUsed;

  LLMUsageStats({required this.providerId, required this.modelId});

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'modelId': modelId,
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'totalInputTokens': totalInputTokens,
    'totalOutputTokens': totalOutputTokens,
    'totalResponseTime': totalResponseTime,
    'averageResponseTime': averageResponseTime,
    'lastUsed': lastUsed?.toIso8601String(),
  };

  factory LLMUsageStats.fromJson(Map<String, dynamic> json) {
    final stats = LLMUsageStats(
      providerId: json['providerId'] as String,
      modelId: json['modelId'] as String,
    );

    stats.totalRequests = json['totalRequests'] as int? ?? 0;
    stats.successfulRequests = json['successfulRequests'] as int? ?? 0;
    stats.failedRequests = json['failedRequests'] as int? ?? 0;
    stats.totalInputTokens = json['totalInputTokens'] as int? ?? 0;
    stats.totalOutputTokens = json['totalOutputTokens'] as int? ?? 0;
    stats.totalResponseTime = json['totalResponseTime'] as int? ?? 0;
    stats.averageResponseTime = json['averageResponseTime'] as double? ?? 0.0;
    stats.lastUsed = json['lastUsed'] != null
        ? DateTime.parse(json['lastUsed'] as String)
        : null;

    return stats;
  }
}

/// Audit event types
enum LLMAuditEventType { interaction, security, provider, system }

/// LLM Rate Limiting Service
///
/// Provides rate limiting and usage controls for LLM interactions
/// to prevent abuse and manage resource consumption.
class LLMRateLimitService {
  

  // Rate limiting state
  final Map<String, List<DateTime>> _requestHistory = {};
  final Map<String, int> _dailyUsage = {};

  // Configuration
  static const int _defaultRequestsPerMinute = 60;
  static const int _defaultRequestsPerHour = 1000;
  static const int _defaultRequestsPerDay = 10000;
  static const int _defaultMaxTokensPerRequest = 4000;

  /// Check if a request is allowed under rate limits
  bool isRequestAllowed({
    required String userId,
    required String providerId,
    int requestsPerMinute = _defaultRequestsPerMinute,
    int requestsPerHour = _defaultRequestsPerHour,
    int requestsPerDay = _defaultRequestsPerDay,
    int? tokenCount,
    int maxTokensPerRequest = _defaultMaxTokensPerRequest,
  }) {
    final key = '$userId:$providerId';
    final now = DateTime.now();

    // Check token limit
    if (tokenCount != null && tokenCount > maxTokensPerRequest) {
      _logger.logTunnelError(
        'RATE_LIMIT_EXCEEDED',
        'Token limit exceeded',
        context: {
          'userId': userId,
          'providerId': providerId,
          'tokenCount': tokenCount,
          'maxTokens': maxTokensPerRequest,
        },
      );
      return false;
    }

    // Get request history for this user/provider
    final history = _requestHistory[key] ?? [];

    // Clean old requests
    history.removeWhere((timestamp) => now.difference(timestamp).inDays >= 1);

    // Check daily limit
    final dailyRequests = history
        .where((timestamp) => now.difference(timestamp).inDays == 0)
        .length;
    if (dailyRequests >= requestsPerDay) {
      _logger.logTunnelError(
        'RATE_LIMIT_EXCEEDED',
        'Daily request limit exceeded',
        context: {
          'userId': userId,
          'providerId': providerId,
          'dailyRequests': dailyRequests,
          'limit': requestsPerDay,
        },
      );
      return false;
    }

    // Check hourly limit
    final hourlyRequests = history
        .where((timestamp) => now.difference(timestamp).inHours == 0)
        .length;
    if (hourlyRequests >= requestsPerHour) {
      _logger.logTunnelError(
        'RATE_LIMIT_EXCEEDED',
        'Hourly request limit exceeded',
        context: {
          'userId': userId,
          'providerId': providerId,
          'hourlyRequests': hourlyRequests,
          'limit': requestsPerHour,
        },
      );
      return false;
    }

    // Check per-minute limit
    final minuteRequests = history
        .where((timestamp) => now.difference(timestamp).inMinutes == 0)
        .length;
    if (minuteRequests >= requestsPerMinute) {
      _logger.logTunnelError(
        'RATE_LIMIT_EXCEEDED',
        'Per-minute request limit exceeded',
        context: {
          'userId': userId,
          'providerId': providerId,
          'minuteRequests': minuteRequests,
          'limit': requestsPerMinute,
        },
      );
      return false;
    }

    return true;
  }

  /// Record a request for rate limiting
  void recordRequest({required String userId, required String providerId}) {
    final key = '$userId:$providerId';
    final history = _requestHistory[key] ?? [];

    history.add(DateTime.now());
    _requestHistory[key] = history;

    // Update daily usage
    final dailyKey =
        '$key:${DateTime.now().toIso8601String().substring(0, 10)}';
    _dailyUsage[dailyKey] = (_dailyUsage[dailyKey] ?? 0) + 1;
  }

  /// Get usage statistics for a user/provider
  Map<String, int> getUsageStats({
    required String userId,
    required String providerId,
  }) {
    final key = '$userId:$providerId';
    final history = _requestHistory[key] ?? [];
    final now = DateTime.now();

    return {
      'requestsToday': history
          .where((timestamp) => now.difference(timestamp).inDays == 0)
          .length,
      'requestsThisHour': history
          .where((timestamp) => now.difference(timestamp).inHours == 0)
          .length,
      'requestsThisMinute': history
          .where((timestamp) => now.difference(timestamp).inMinutes == 0)
          .length,
    };
  }

  /// Clear rate limiting data for a user
  void clearUserData(String userId) {
    _requestHistory.removeWhere((key, _) => key.startsWith('$userId:'));
    _dailyUsage.removeWhere((key, _) => key.startsWith('$userId:'));
  }
}

