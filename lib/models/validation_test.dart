/// Individual validation test result with detailed information
///
/// Represents the result of a single validation test including
/// success status, timing, and detailed error information.
class ValidationTest {
  final String name;
  final bool isSuccess;
  final String message;
  final int? duration;
  final String? error;
  final String? category;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  ValidationTest({
    required this.name,
    required this.isSuccess,
    required this.message,
    this.duration,
    this.error,
    this.category,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a successful test result
  factory ValidationTest.success(
    String name,
    String message, {
    int? duration,
    String? category,
    Map<String, dynamic>? details,
  }) {
    return ValidationTest(
      name: name,
      isSuccess: true,
      message: message,
      duration: duration,
      category: category,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  /// Create a failed test result
  factory ValidationTest.failure(
    String name,
    String message, {
    String? error,
    int? duration,
    String? category,
    Map<String, dynamic>? details,
  }) {
    return ValidationTest(
      name: name,
      isSuccess: false,
      message: message,
      error: error,
      duration: duration,
      category: category,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  /// Create a test result with custom status
  factory ValidationTest.custom({
    required String name,
    required bool isSuccess,
    required String message,
    String? error,
    int? duration,
    String? category,
    Map<String, dynamic>? details,
  }) {
    return ValidationTest(
      name: name,
      isSuccess: isSuccess,
      message: message,
      error: error,
      duration: duration,
      category: category,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  /// Get the status as a string
  String get status => isSuccess ? 'PASSED' : 'FAILED';

  /// Get the duration as a formatted string
  String get durationString {
    if (duration == null) return 'N/A';
    if (duration! < 1000) return '${duration}ms';
    return '${(duration! / 1000).toStringAsFixed(1)}s';
  }

  /// Check if this test has detailed information
  bool get hasDetails => details != null && details!.isNotEmpty;

  /// Check if this test has error information
  bool get hasError => error != null && error!.isNotEmpty;

  /// Get a summary of the test result
  Map<String, dynamic> get summary {
    return {
      'name': name,
      'status': status,
      'isSuccess': isSuccess,
      'message': message,
      'duration': duration,
      'durationString': durationString,
      'category': category,
      'hasDetails': hasDetails,
      'hasError': hasError,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isSuccess': isSuccess,
      'message': message,
      'duration': duration,
      'error': error,
      'category': category,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
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
      category: json['category'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Create a copy with updated values
  ValidationTest copyWith({
    String? name,
    bool? isSuccess,
    String? message,
    int? duration,
    String? error,
    String? category,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  }) {
    return ValidationTest(
      name: name ?? this.name,
      isSuccess: isSuccess ?? this.isSuccess,
      message: message ?? this.message,
      duration: duration ?? this.duration,
      error: error ?? this.error,
      category: category ?? this.category,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Compare tests by name
  int compareTo(ValidationTest other) {
    return name.compareTo(other.name);
  }

  /// Get detailed error information
  String get detailedError {
    if (!hasError) return 'No error information available';
    
    final buffer = StringBuffer();
    buffer.writeln('Error: $error');
    
    if (hasDetails) {
      buffer.writeln('Details:');
      details!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }
    
    return buffer.toString().trim();
  }

  /// Get formatted test result for display
  String get formattedResult {
    final buffer = StringBuffer();
    buffer.writeln('Test: $name');
    buffer.writeln('Status: $status');
    buffer.writeln('Message: $message');
    
    if (duration != null) {
      buffer.writeln('Duration: $durationString');
    }
    
    if (category != null) {
      buffer.writeln('Category: $category');
    }
    
    if (hasError) {
      buffer.writeln('Error: $error');
    }
    
    if (hasDetails) {
      buffer.writeln('Details:');
      details!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }
    
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    
    return buffer.toString().trim();
  }

  @override
  String toString() {
    return 'ValidationTest(name: $name, isSuccess: $isSuccess, message: $message, '
           'duration: ${duration}ms, category: $category, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ValidationTest &&
           other.name == name &&
           other.isSuccess == isSuccess &&
           other.message == message &&
           other.duration == duration &&
           other.error == error &&
           other.category == category;
  }

  @override
  int get hashCode {
    return Object.hash(name, isSuccess, message, duration, error, category);
  }
}
