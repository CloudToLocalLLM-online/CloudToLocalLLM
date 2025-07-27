/// Result of tunnel connection validation with detailed test information
///
/// Contains the overall validation result and individual test results
/// for comprehensive tunnel connection testing.
class TunnelValidationResult {
  final bool isSuccess;
  final String message;
  final int? latency;
  final List<ValidationTest> tests;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const TunnelValidationResult({
    required this.isSuccess,
    required this.message,
    this.latency,
    this.tests = const [],
    required this.timestamp,
    this.metadata,
  });

  /// Create a successful validation result
  factory TunnelValidationResult.success(
    String message, {
    int? latency,
    List<ValidationTest>? tests,
    Map<String, dynamic>? metadata,
  }) {
    return TunnelValidationResult(
      isSuccess: true,
      message: message,
      latency: latency,
      tests: tests ?? [],
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create a failed validation result
  factory TunnelValidationResult.failure(
    String message, {
    List<ValidationTest>? tests,
    Map<String, dynamic>? metadata,
  }) {
    return TunnelValidationResult(
      isSuccess: false,
      message: message,
      tests: tests ?? [],
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

  /// Get a summary of the validation result
  Map<String, dynamic> get summary {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'latency': latency,
      'totalTests': tests.length,
      'successfulTests': successfulTestCount,
      'failedTests': failedTestCount,
      'successRate': successRate,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'latency': latency,
      'tests': tests.map((test) => test.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory TunnelValidationResult.fromJson(Map<String, dynamic> json) {
    return TunnelValidationResult(
      isSuccess: json['isSuccess'] as bool,
      message: json['message'] as String,
      latency: json['latency'] as int?,
      tests:
          (json['tests'] as List<dynamic>?)
              ?.map(
                (test) => ValidationTest.fromJson(test as Map<String, dynamic>),
              )
              .toList() ??
          [],
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'TunnelValidationResult(isSuccess: $isSuccess, message: $message, '
        'latency: ${latency}ms, tests: ${tests.length}, timestamp: $timestamp)';
  }
}

/// Individual validation test result
class ValidationTest {
  final String name;
  final bool isSuccess;
  final String message;
  final int? duration;
  final String? error;
  final Map<String, dynamic>? details;

  const ValidationTest({
    required this.name,
    required this.isSuccess,
    required this.message,
    this.duration,
    this.error,
    this.details,
  });

  /// Create a successful test result
  factory ValidationTest.success(
    String name,
    String message, {
    int? duration,
    Map<String, dynamic>? details,
  }) {
    return ValidationTest(
      name: name,
      isSuccess: true,
      message: message,
      duration: duration,
      details: details,
    );
  }

  /// Create a failed test result
  factory ValidationTest.failure(
    String name,
    String message, {
    String? error,
    int? duration,
    Map<String, dynamic>? details,
  }) {
    return ValidationTest(
      name: name,
      isSuccess: false,
      message: message,
      error: error,
      duration: duration,
      details: details,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isSuccess': isSuccess,
      'message': message,
      'duration': duration,
      'error': error,
      'details': details,
    };
  }

  /// Create from JSON
  factory ValidationTest.fromJson(Map<String, dynamic> json) {
    return ValidationTest(
      name: json['name'] as String,
      isSuccess: json['isSuccess'] as bool,
      message: json['message'] as String,
      duration: json['duration'] as int?,
      error: json['error'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ValidationTest(name: $name, isSuccess: $isSuccess, message: $message, '
        'duration: ${duration}ms, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ValidationTest &&
        other.name == name &&
        other.isSuccess == isSuccess &&
        other.message == message &&
        other.duration == duration &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(name, isSuccess, message, duration, error);
  }
}
