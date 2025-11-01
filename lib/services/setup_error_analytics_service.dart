import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import '../models/setup_error.dart';
import 'setup_troubleshooting_service.dart';

/// Service for logging and analyzing setup errors for improvement
///
/// This service provides:
/// - Error logging with privacy-compliant data collection
/// - Analytics for setup success rates and common issues
/// - Performance metrics and timing analysis
/// - Feedback integration for continuous improvement
class SetupErrorAnalyticsService extends ChangeNotifier {
  static const String _errorLogKey = 'cloudtolocalllm_error_log';
  static const String _analyticsKey = 'cloudtolocalllm_analytics';
  static const String _sessionKey = 'cloudtolocalllm_session';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final List<SetupErrorLogEntry> _errorLog = [];
  final Map<String, SetupSessionAnalytics> _sessionAnalytics = {};
  final StreamController<SetupErrorLogEntry> _errorLogController =
      StreamController<SetupErrorLogEntry>.broadcast();

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  SetupAnalyticsConfig _config = const SetupAnalyticsConfig();

  /// Stream of error log entries for real-time monitoring
  Stream<SetupErrorLogEntry> get errorLogStream => _errorLogController.stream;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Get error log entries
  List<SetupErrorLogEntry> get errorLog => List.unmodifiable(_errorLog);

  /// Initialize the analytics service
  Future<void> initialize({SetupAnalyticsConfig? config}) async {
    if (config != null) {
      _config = config;
    }

    await _loadStoredData();
    _startNewSession();

    debugPrint(' [Analytics] Setup error analytics service initialized');
  }

  /// Start a new setup session
  void _startNewSession() {
    _currentSessionId = _generateSessionId();
    _sessionStartTime = DateTime.now();

    debugPrint(' [Analytics] Started new setup session: $_currentSessionId');
  }

  /// Log a setup error
  Future<void> logError(
    SetupError error, {
    Map<String, dynamic> additionalContext = const {},
  }) async {
    if (!_config.enableErrorLogging) return;

    final logEntry = SetupErrorLogEntry(
      id: _generateLogEntryId(),
      sessionId: _currentSessionId,
      error: error,
      timestamp: DateTime.now(),
      userAgent: _getUserAgent(),
      platform: _getPlatform(),
      additionalContext: additionalContext,
    );

    _errorLog.add(logEntry);
    _errorLogController.add(logEntry);

    // Update session analytics
    if (_currentSessionId != null) {
      _updateSessionAnalytics(_currentSessionId!, error);
    }

    // Persist to storage
    await _persistErrorLog();

    debugPrint(
      ' [Analytics] Logged error: ${error.code} in session: $_currentSessionId',
    );
    notifyListeners();
  }

  /// Log setup step completion
  Future<void> logStepCompletion(
    String stepName, {
    Duration? duration,
    bool success = true,
    Map<String, dynamic> context = const {},
  }) async {
    if (!_config.enableStepTracking) return;

    final stepLog = SetupStepLogEntry(
      id: _generateLogEntryId(),
      sessionId: _currentSessionId,
      stepName: stepName,
      success: success,
      duration: duration,
      timestamp: DateTime.now(),
      context: context,
    );

    // Update session analytics
    if (_currentSessionId != null) {
      _updateSessionStepAnalytics(_currentSessionId!, stepLog);
    }

    debugPrint(
      ' [Analytics] Logged step completion: $stepName (success: $success)',
    );
  }

  /// Log troubleshooting feedback
  Future<void> logTroubleshootingFeedback(
    TroubleshootingFeedback feedback,
  ) async {
    if (!_config.enableFeedbackLogging) return;

    final feedbackLog = TroubleshootingFeedbackLogEntry(
      id: _generateLogEntryId(),
      sessionId: _currentSessionId,
      feedback: feedback,
      timestamp: DateTime.now(),
    );

    // Update session analytics
    if (_currentSessionId != null) {
      _updateSessionFeedbackAnalytics(_currentSessionId!, feedbackLog);
    }

    debugPrint(
      ' [Analytics] Logged troubleshooting feedback: ${feedback.wasHelpful}',
    );
  }

  /// Complete the current setup session
  Future<void> completeSession({
    bool success = false,
    String? finalStep,
    Map<String, dynamic> context = const {},
  }) async {
    if (_currentSessionId == null || _sessionStartTime == null) return;

    final sessionDuration = DateTime.now().difference(_sessionStartTime!);

    final sessionAnalytics =
        _sessionAnalytics[_currentSessionId!] ??
        SetupSessionAnalytics(
          sessionId: _currentSessionId!,
          startTime: _sessionStartTime!,
          platform: _getPlatform(),
        );

    final completedSession = sessionAnalytics.copyWith(
      endTime: DateTime.now(),
      success: success,
      finalStep: finalStep,
      totalDuration: sessionDuration,
      context: {...sessionAnalytics.context, ...context},
    );

    _sessionAnalytics[_currentSessionId!] = completedSession;
    await _persistSessionAnalytics();

    debugPrint(
      ' [Analytics] Completed session: $_currentSessionId (success: $success, duration: ${sessionDuration.inSeconds}s)',
    );

    // Start new session for potential retry
    _startNewSession();
    notifyListeners();
  }

  /// Get analytics summary
  SetupAnalyticsSummary getAnalyticsSummary({
    DateTime? since,
    String? platform,
  }) {
    final filteredSessions = _sessionAnalytics.values.where((session) {
      if (since != null && session.startTime.isBefore(since)) return false;
      if (platform != null && session.platform != platform) return false;
      return true;
    }).toList();

    final filteredErrors = _errorLog.where((error) {
      if (since != null && error.timestamp.isBefore(since)) return false;
      if (platform != null && error.platform != platform) return false;
      return true;
    }).toList();

    return SetupAnalyticsSummary(
      totalSessions: filteredSessions.length,
      successfulSessions: filteredSessions.where((s) => s.success).length,
      totalErrors: filteredErrors.length,
      errorsByType: _groupErrorsByType(filteredErrors),
      errorsByStep: _groupErrorsByStep(filteredErrors),
      averageSessionDuration: _calculateAverageSessionDuration(
        filteredSessions,
      ),
      mostCommonErrors: _getMostCommonErrors(filteredErrors),
      platformDistribution: _getPlatformDistribution(filteredSessions),
      stepCompletionRates: _getStepCompletionRates(filteredSessions),
    );
  }

  /// Get error trends over time
  List<SetupErrorTrend> getErrorTrends({
    Duration period = const Duration(days: 7),
    String? errorType,
  }) {
    final now = DateTime.now();
    final startTime = now.subtract(period);

    final relevantErrors = _errorLog.where((error) {
      if (error.timestamp.isBefore(startTime)) return false;
      if (errorType != null && error.error.type.name != errorType) return false;
      return true;
    }).toList();

    // Group errors by day
    final errorsByDay = <DateTime, int>{};
    for (final error in relevantErrors) {
      final day = DateTime(
        error.timestamp.year,
        error.timestamp.month,
        error.timestamp.day,
      );
      errorsByDay[day] = (errorsByDay[day] ?? 0) + 1;
    }

    return errorsByDay.entries
        .map(
          (entry) => SetupErrorTrend(date: entry.key, errorCount: entry.value),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Export analytics data (privacy-compliant)
  Map<String, dynamic> exportAnalyticsData({bool includePersonalData = false}) {
    final export = <String, dynamic>{
      'summary': getAnalyticsSummary().toJson(),
      'errorTrends': getErrorTrends().map((t) => t.toJson()).toList(),
      'config': _config.toJson(),
      'exportTimestamp': DateTime.now().toIso8601String(),
    };

    if (includePersonalData && _config.allowPersonalDataExport) {
      export['sessions'] = _sessionAnalytics.values
          .map((s) => s.toJson())
          .toList();
      export['errorLog'] = _errorLog.map((e) => e.toJson()).toList();
    }

    return export;
  }

  /// Clear analytics data
  Future<void> clearAnalyticsData() async {
    _errorLog.clear();
    _sessionAnalytics.clear();

    await _secureStorage.delete(key: _errorLogKey);
    await _secureStorage.delete(key: _analyticsKey);
    await _secureStorage.delete(key: _sessionKey);

    debugPrint(' [Analytics] Cleared all analytics data');
    notifyListeners();
  }

  /// Update analytics configuration
  void updateConfig(SetupAnalyticsConfig config) {
    _config = config;
    debugPrint(' [Analytics] Updated configuration');
    notifyListeners();
  }

  // Private helper methods

  Future<void> _loadStoredData() async {
    try {
      // Load error log
      final errorLogJson = await _secureStorage.read(key: _errorLogKey);
      if (errorLogJson != null) {
        final errorLogData = jsonDecode(errorLogJson) as List;
        _errorLog.addAll(
          errorLogData.map(
            (e) => SetupErrorLogEntry.fromJson(e as Map<String, dynamic>),
          ),
        );
      }

      // Load session analytics
      final analyticsJson = await _secureStorage.read(key: _analyticsKey);
      if (analyticsJson != null) {
        final analyticsData = jsonDecode(analyticsJson) as Map<String, dynamic>;
        for (final entry in analyticsData.entries) {
          _sessionAnalytics[entry.key] = SetupSessionAnalytics.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      debugPrint(
        ' [Analytics] Loaded ${_errorLog.length} error entries and ${_sessionAnalytics.length} sessions',
      );
    } catch (e) {
      debugPrint(' [Analytics] Error loading stored data: $e');
    }
  }

  Future<void> _persistErrorLog() async {
    if (!_config.enablePersistence) return;

    try {
      // Keep only recent entries to prevent storage bloat
      final recentErrors = _errorLog
          .where(
            (e) =>
                DateTime.now().difference(e.timestamp).inDays <
                _config.dataRetentionDays,
          )
          .toList();

      final errorLogJson = jsonEncode(
        recentErrors.map((e) => e.toJson()).toList(),
      );
      await _secureStorage.write(key: _errorLogKey, value: errorLogJson);
    } catch (e) {
      debugPrint(' [Analytics] Error persisting error log: $e');
    }
  }

  Future<void> _persistSessionAnalytics() async {
    if (!_config.enablePersistence) return;

    try {
      // Keep only recent sessions
      final recentSessions = Map.fromEntries(
        _sessionAnalytics.entries.where(
          (e) =>
              DateTime.now().difference(e.value.startTime).inDays <
              _config.dataRetentionDays,
        ),
      );

      final analyticsJson = jsonEncode(
        recentSessions.map((k, v) => MapEntry(k, v.toJson())),
      );
      await _secureStorage.write(key: _analyticsKey, value: analyticsJson);
    } catch (e) {
      debugPrint(' [Analytics] Error persisting session analytics: $e');
    }
  }

  void _updateSessionAnalytics(String sessionId, SetupError error) {
    final existing =
        _sessionAnalytics[sessionId] ??
        SetupSessionAnalytics(
          sessionId: sessionId,
          startTime: _sessionStartTime ?? DateTime.now(),
          platform: _getPlatform(),
        );

    _sessionAnalytics[sessionId] = existing.copyWith(
      errorCount: existing.errorCount + 1,
      errors: [...existing.errors, error],
    );
  }

  void _updateSessionStepAnalytics(
    String sessionId,
    SetupStepLogEntry stepLog,
  ) {
    final existing =
        _sessionAnalytics[sessionId] ??
        SetupSessionAnalytics(
          sessionId: sessionId,
          startTime: _sessionStartTime ?? DateTime.now(),
          platform: _getPlatform(),
        );

    _sessionAnalytics[sessionId] = existing.copyWith(
      completedSteps: [...existing.completedSteps, stepLog.stepName],
      stepLogs: [...existing.stepLogs, stepLog],
    );
  }

  void _updateSessionFeedbackAnalytics(
    String sessionId,
    TroubleshootingFeedbackLogEntry feedbackLog,
  ) {
    final existing =
        _sessionAnalytics[sessionId] ??
        SetupSessionAnalytics(
          sessionId: sessionId,
          startTime: _sessionStartTime ?? DateTime.now(),
          platform: _getPlatform(),
        );

    _sessionAnalytics[sessionId] = existing.copyWith(
      feedbackLogs: [...existing.feedbackLogs, feedbackLog],
    );
  }

  Map<SetupErrorType, int> _groupErrorsByType(List<SetupErrorLogEntry> errors) {
    final grouped = <SetupErrorType, int>{};
    for (final error in errors) {
      grouped[error.error.type] = (grouped[error.error.type] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, int> _groupErrorsByStep(List<SetupErrorLogEntry> errors) {
    final grouped = <String, int>{};
    for (final error in errors) {
      final step = error.error.setupStep ?? 'unknown';
      grouped[step] = (grouped[step] ?? 0) + 1;
    }
    return grouped;
  }

  Duration? _calculateAverageSessionDuration(
    List<SetupSessionAnalytics> sessions,
  ) {
    final completedSessions = sessions
        .where((s) => s.totalDuration != null)
        .toList();
    if (completedSessions.isEmpty) return null;

    final totalMs = completedSessions
        .map((s) => s.totalDuration!.inMilliseconds)
        .reduce((a, b) => a + b);

    return Duration(milliseconds: totalMs ~/ completedSessions.length);
  }

  List<SetupErrorSummary> _getMostCommonErrors(
    List<SetupErrorLogEntry> errors,
  ) {
    final errorCounts = <String, int>{};
    final errorDetails = <String, SetupError>{};

    for (final error in errors) {
      errorCounts[error.error.code] = (errorCounts[error.error.code] ?? 0) + 1;
      errorDetails[error.error.code] = error.error;
    }

    final sortedErrors = errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedErrors
        .take(10)
        .map(
          (entry) => SetupErrorSummary(
            error: errorDetails[entry.key]!,
            count: entry.value,
          ),
        )
        .toList();
  }

  Map<String, int> _getPlatformDistribution(
    List<SetupSessionAnalytics> sessions,
  ) {
    final distribution = <String, int>{};
    for (final session in sessions) {
      distribution[session.platform] =
          (distribution[session.platform] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, double> _getStepCompletionRates(
    List<SetupSessionAnalytics> sessions,
  ) {
    final stepAttempts = <String, int>{};
    final stepCompletions = <String, int>{};

    for (final session in sessions) {
      for (final stepLog in session.stepLogs) {
        stepAttempts[stepLog.stepName] =
            (stepAttempts[stepLog.stepName] ?? 0) + 1;
        if (stepLog.success) {
          stepCompletions[stepLog.stepName] =
              (stepCompletions[stepLog.stepName] ?? 0) + 1;
        }
      }
    }

    final completionRates = <String, double>{};
    for (final step in stepAttempts.keys) {
      final attempts = stepAttempts[step]!;
      final completions = stepCompletions[step] ?? 0;
      completionRates[step] = attempts > 0 ? completions / attempts : 0.0;
    }

    return completionRates;
  }

  String _generateSessionId() {
    return 'setup_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateLogEntryId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}_${_errorLog.length}';
  }

  String _getUserAgent() {
    // In a real implementation, you would get this from the browser
    return kIsWeb ? 'Web' : 'Desktop';
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  @override
  void dispose() {
    _errorLogController.close();
    super.dispose();
  }
}

// Supporting data classes

@immutable
class SetupAnalyticsConfig {
  final bool enableErrorLogging;
  final bool enableStepTracking;
  final bool enableFeedbackLogging;
  final bool enablePersistence;
  final bool allowPersonalDataExport;
  final int dataRetentionDays;

  const SetupAnalyticsConfig({
    this.enableErrorLogging = true,
    this.enableStepTracking = true,
    this.enableFeedbackLogging = true,
    this.enablePersistence = true,
    this.allowPersonalDataExport = false,
    this.dataRetentionDays = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'enableErrorLogging': enableErrorLogging,
      'enableStepTracking': enableStepTracking,
      'enableFeedbackLogging': enableFeedbackLogging,
      'enablePersistence': enablePersistence,
      'allowPersonalDataExport': allowPersonalDataExport,
      'dataRetentionDays': dataRetentionDays,
    };
  }
}

@immutable
class SetupErrorLogEntry {
  final String id;
  final String? sessionId;
  final SetupError error;
  final DateTime timestamp;
  final String userAgent;
  final String platform;
  final Map<String, dynamic> additionalContext;

  const SetupErrorLogEntry({
    required this.id,
    this.sessionId,
    required this.error,
    required this.timestamp,
    required this.userAgent,
    required this.platform,
    this.additionalContext = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'error': error.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'userAgent': userAgent,
      'platform': platform,
      'additionalContext': additionalContext,
    };
  }

  factory SetupErrorLogEntry.fromJson(Map<String, dynamic> json) {
    return SetupErrorLogEntry(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String?,
      error: SetupError.fromJson(json['error'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      userAgent: json['userAgent'] as String,
      platform: json['platform'] as String,
      additionalContext: Map<String, dynamic>.from(
        json['additionalContext'] ?? {},
      ),
    );
  }
}

@immutable
class SetupStepLogEntry {
  final String id;
  final String? sessionId;
  final String stepName;
  final bool success;
  final Duration? duration;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  const SetupStepLogEntry({
    required this.id,
    this.sessionId,
    required this.stepName,
    required this.success,
    this.duration,
    required this.timestamp,
    this.context = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'stepName': stepName,
      'success': success,
      'duration': duration?.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
    };
  }
}

@immutable
class TroubleshootingFeedbackLogEntry {
  final String id;
  final String? sessionId;
  final TroubleshootingFeedback feedback;
  final DateTime timestamp;

  const TroubleshootingFeedbackLogEntry({
    required this.id,
    this.sessionId,
    required this.feedback,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'feedback': feedback.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

@immutable
class SetupSessionAnalytics {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final String platform;
  final bool success;
  final String? finalStep;
  final int errorCount;
  final List<SetupError> errors;
  final List<String> completedSteps;
  final List<SetupStepLogEntry> stepLogs;
  final List<TroubleshootingFeedbackLogEntry> feedbackLogs;
  final Duration? totalDuration;
  final Map<String, dynamic> context;

  const SetupSessionAnalytics({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.platform,
    this.success = false,
    this.finalStep,
    this.errorCount = 0,
    this.errors = const [],
    this.completedSteps = const [],
    this.stepLogs = const [],
    this.feedbackLogs = const [],
    this.totalDuration,
    this.context = const {},
  });

  SetupSessionAnalytics copyWith({
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? platform,
    bool? success,
    String? finalStep,
    int? errorCount,
    List<SetupError>? errors,
    List<String>? completedSteps,
    List<SetupStepLogEntry>? stepLogs,
    List<TroubleshootingFeedbackLogEntry>? feedbackLogs,
    Duration? totalDuration,
    Map<String, dynamic>? context,
  }) {
    return SetupSessionAnalytics(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      platform: platform ?? this.platform,
      success: success ?? this.success,
      finalStep: finalStep ?? this.finalStep,
      errorCount: errorCount ?? this.errorCount,
      errors: errors ?? this.errors,
      completedSteps: completedSteps ?? this.completedSteps,
      stepLogs: stepLogs ?? this.stepLogs,
      feedbackLogs: feedbackLogs ?? this.feedbackLogs,
      totalDuration: totalDuration ?? this.totalDuration,
      context: context ?? this.context,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'platform': platform,
      'success': success,
      'finalStep': finalStep,
      'errorCount': errorCount,
      'errors': errors.map((e) => e.toJson()).toList(),
      'completedSteps': completedSteps,
      'stepLogs': stepLogs.map((s) => s.toJson()).toList(),
      'feedbackLogs': feedbackLogs.map((f) => f.toJson()).toList(),
      'totalDuration': totalDuration?.inMilliseconds,
      'context': context,
    };
  }

  factory SetupSessionAnalytics.fromJson(Map<String, dynamic> json) {
    return SetupSessionAnalytics(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      platform: json['platform'] as String,
      success: json['success'] as bool? ?? false,
      finalStep: json['finalStep'] as String?,
      errorCount: json['errorCount'] as int? ?? 0,
      errors: (json['errors'] as List? ?? [])
          .map((e) => SetupError.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedSteps: List<String>.from(json['completedSteps'] ?? []),
      stepLogs: (json['stepLogs'] as List? ?? [])
          .map(
            (s) => SetupStepLogEntry(
              id: s['id'] as String,
              sessionId: s['sessionId'] as String?,
              stepName: s['stepName'] as String,
              success: s['success'] as bool,
              duration: s['duration'] != null
                  ? Duration(milliseconds: s['duration'] as int)
                  : null,
              timestamp: DateTime.parse(s['timestamp'] as String),
              context: Map<String, dynamic>.from(s['context'] ?? {}),
            ),
          )
          .toList(),
      feedbackLogs: (json['feedbackLogs'] as List? ?? [])
          .map(
            (f) => TroubleshootingFeedbackLogEntry(
              id: f['id'] as String,
              sessionId: f['sessionId'] as String?,
              feedback: TroubleshootingFeedback(
                sessionId: f['feedback']['sessionId'] as String,
                wasHelpful: f['feedback']['wasHelpful'] as bool,
                comment: f['feedback']['comment'] as String?,
                helpfulGuides: List<String>.from(
                  f['feedback']['helpfulGuides'] ?? [],
                ),
                unhelpfulGuides: List<String>.from(
                  f['feedback']['unhelpfulGuides'] ?? [],
                ),
                timestamp: DateTime.parse(f['feedback']['timestamp'] as String),
              ),
              timestamp: DateTime.parse(f['timestamp'] as String),
            ),
          )
          .toList(),
      totalDuration: json['totalDuration'] != null
          ? Duration(milliseconds: json['totalDuration'] as int)
          : null,
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}

@immutable
class SetupAnalyticsSummary {
  final int totalSessions;
  final int successfulSessions;
  final int totalErrors;
  final Map<SetupErrorType, int> errorsByType;
  final Map<String, int> errorsByStep;
  final Duration? averageSessionDuration;
  final List<SetupErrorSummary> mostCommonErrors;
  final Map<String, int> platformDistribution;
  final Map<String, double> stepCompletionRates;

  const SetupAnalyticsSummary({
    required this.totalSessions,
    required this.successfulSessions,
    required this.totalErrors,
    required this.errorsByType,
    required this.errorsByStep,
    this.averageSessionDuration,
    required this.mostCommonErrors,
    required this.platformDistribution,
    required this.stepCompletionRates,
  });

  double get successRate {
    return totalSessions > 0 ? successfulSessions / totalSessions : 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'successfulSessions': successfulSessions,
      'successRate': successRate,
      'totalErrors': totalErrors,
      'errorsByType': errorsByType.map((k, v) => MapEntry(k.name, v)),
      'errorsByStep': errorsByStep,
      'averageSessionDuration': averageSessionDuration?.inSeconds,
      'mostCommonErrors': mostCommonErrors.map((e) => e.toJson()).toList(),
      'platformDistribution': platformDistribution,
      'stepCompletionRates': stepCompletionRates,
    };
  }
}

@immutable
class SetupErrorSummary {
  final SetupError error;
  final int count;

  const SetupErrorSummary({required this.error, required this.count});

  Map<String, dynamic> toJson() {
    return {'error': error.toJson(), 'count': count};
  }
}

@immutable
class SetupErrorTrend {
  final DateTime date;
  final int errorCount;

  const SetupErrorTrend({required this.date, required this.errorCount});

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'errorCount': errorCount};
  }
}
