import 'validation_test.dart';

/// Result of comprehensive connection validation with detailed test information
///
/// Contains the overall validation result and individual test results
/// for comprehensive connection validation testing.
class ValidationResult {
  final bool isSuccess;
  final String message;
  final List<ValidationTest> tests;
  final int? duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ValidationResult({
    required this.isSuccess,
    required this.message,
    required this.tests,
    this.duration,
    required this.timestamp,
    this.metadata,
  });

  /// Create a successful validation result
  factory ValidationResult.success(
    String message, {
    List<ValidationTest>? tests,
    int? duration,
    Map<String, dynamic>? metadata,
  }) {
    return ValidationResult(
      isSuccess: true,
      message: message,
      tests: tests ?? [],
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create a failed validation result
  factory ValidationResult.failure(
    String message, {
    List<ValidationTest>? tests,
    int? duration,
    Map<String, dynamic>? metadata,
  }) {
    return ValidationResult(
      isSuccess: false,
      message: message,
      tests: tests ?? [],
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Get the number of successful tests
  int get successfulTestCount {
    return tests.where((test) => test.isSuccess).length;
  }

  /// Get the number of failed tests
  int get failedTestCount {
    return tests.where((test) => !test.isSuccess).length;
  }

  /// Get the overall success rate
  double get successRate {
    if (tests.isEmpty) return isSuccess ? 1.0 : 0.0;
    return successfulTestCount / tests.length;
  }

  /// Get failed tests
  List<ValidationTest> get failedTests {
    return tests.where((test) => !test.isSuccess).toList();
  }

  /// Get successful tests
  List<ValidationTest> get successfulTests {
    return tests.where((test) => test.isSuccess).toList();
  }

  /// Get tests by category
  List<ValidationTest> getTestsByCategory(String category) {
    return tests.where((test) => test.category == category).toList();
  }

  /// Check if a specific test passed
  bool hasTestPassed(String testName) {
    final test = tests.where((t) => t.name == testName).firstOrNull;
    return test?.isSuccess ?? false;
  }

  /// Get a specific test result
  ValidationTest? getTest(String testName) {
    return tests.where((t) => t.name == testName).firstOrNull;
  }

  /// Get a summary of the validation result
  Map<String, dynamic> get summary {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'duration': duration,
      'totalTests': tests.length,
      'successfulTests': successfulTestCount,
      'failedTests': failedTestCount,
      'successRate': successRate,
      'timestamp': timestamp.toIso8601String(),
      'categories': _getTestCategories(),
    };
  }

  /// Get test categories and their success rates
  Map<String, Map<String, dynamic>> _getTestCategories() {
    final categories = <String, List<ValidationTest>>{};
    
    for (final test in tests) {
      final category = test.category ?? 'general';
      categories.putIfAbsent(category, () => []).add(test);
    }

    return categories.map((category, tests) {
      final successful = tests.where((test) => test.isSuccess).length;
      return MapEntry(category, {
        'total': tests.length,
        'successful': successful,
        'failed': tests.length - successful,
        'successRate': tests.isEmpty ? 0.0 : successful / tests.length,
      });
    });
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'tests': tests.map((test) => test.toJson()).toList(),
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      isSuccess: json['isSuccess'] as bool,
      message: json['message'] as String,
      tests: (json['tests'] as List<dynamic>?)
          ?.map((test) => ValidationTest.fromJson(test as Map<String, dynamic>))
          .toList() ?? [],
      duration: json['duration'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated values
  ValidationResult copyWith({
    bool? isSuccess,
    String? message,
    List<ValidationTest>? tests,
    int? duration,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ValidationResult(
      isSuccess: isSuccess ?? this.isSuccess,
      message: message ?? this.message,
      tests: tests ?? this.tests,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ValidationResult(isSuccess: $isSuccess, message: $message, '
           'tests: ${tests.length}, duration: ${duration}ms, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ValidationResult &&
           other.isSuccess == isSuccess &&
           other.message == message &&
           other.duration == duration &&
           other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(isSuccess, message, duration, timestamp);
  }
}
