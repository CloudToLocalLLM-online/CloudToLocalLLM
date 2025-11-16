/// Diagnostic Report
/// Diagnostic test results and recommendations
library;

/// Diagnostic test types
enum DiagnosticTestType {
  dnsResolution,
  websocketConnectivity,
  sshAuthentication,
  tunnelEstablishment,
  dataTransfer,
  latencyTest,
  throughputTest,
}

/// Diagnostic test result
class DiagnosticTest {
  final String name;
  final String description;
  final bool passed;
  final Duration duration;
  final String? errorMessage;
  final Map<String, dynamic>? details;

  const DiagnosticTest({
    required this.name,
    required this.description,
    required this.passed,
    required this.duration,
    this.errorMessage,
    this.details,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'passed': passed,
      'duration': duration.inMilliseconds,
      'errorMessage': errorMessage,
      'details': details,
    };
  }
}

/// Diagnostic summary
class DiagnosticSummary {
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final Duration totalDuration;
  final List<String> recommendations;

  const DiagnosticSummary({
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.totalDuration,
    required this.recommendations,
  });

  /// Calculate pass rate
  double get passRate {
    if (totalTests == 0) return 0.0;
    return passedTests / totalTests;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalTests': totalTests,
      'passedTests': passedTests,
      'failedTests': failedTests,
      'totalDuration': totalDuration.inMilliseconds,
      'passRate': passRate,
      'recommendations': recommendations,
    };
  }
}

/// Diagnostic report
class DiagnosticReport {
  final DateTime timestamp;
  final List<DiagnosticTest> tests;
  final DiagnosticSummary summary;

  const DiagnosticReport({
    required this.timestamp,
    required this.tests,
    required this.summary,
  });

  /// Check if all tests passed
  bool get allTestsPassed => tests.every((t) => t.passed);

  /// Get failed tests
  List<DiagnosticTest> get failedTests =>
      tests.where((t) => !t.passed).toList();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'tests': tests.map((t) => t.toJson()).toList(),
      'summary': summary.toJson(),
      'allTestsPassed': allTestsPassed,
    };
  }
}
