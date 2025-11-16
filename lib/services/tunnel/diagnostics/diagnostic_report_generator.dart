/// Diagnostic Report Generator
/// Aggregates test results and generates comprehensive reports with recommendations
library;

import '../interfaces/diagnostic_report.dart';

/// Diagnostic report generator
/// Creates comprehensive diagnostic reports with recommendations
class DiagnosticReportGenerator {
  /// Generate a diagnostic report from test results
  static DiagnosticReport generateReport(List<DiagnosticTest> tests) {
    final timestamp = DateTime.now();
    final summary = _generateSummary(tests);

    return DiagnosticReport(
      timestamp: timestamp,
      tests: tests,
      summary: summary,
    );
  }

  /// Generate summary from test results
  static DiagnosticSummary _generateSummary(List<DiagnosticTest> tests) {
    final totalTests = tests.length;
    final passedTests = tests.where((t) => t.passed).length;
    final failedTests = totalTests - passedTests;

    final totalDuration = tests.fold<Duration>(
      Duration.zero,
      (sum, test) => sum + test.duration,
    );

    final recommendations = _generateRecommendations(tests);

    return DiagnosticSummary(
      totalTests: totalTests,
      passedTests: passedTests,
      failedTests: failedTests,
      totalDuration: totalDuration,
      recommendations: recommendations,
    );
  }

  /// Generate recommendations based on test results
  static List<String> _generateRecommendations(List<DiagnosticTest> tests) {
    final recommendations = <String>[];
    final failedTests = tests.where((t) => !t.passed).toList();

    if (failedTests.isEmpty) {
      recommendations
          .add('✓ All tests passed! Your tunnel connection is healthy.');
      return recommendations;
    }

    // Check for DNS issues
    final dnsTest = tests.firstWhere(
      (t) => t.name == 'DNS Resolution',
      orElse: () => tests.first,
    );
    if (!dnsTest.passed) {
      recommendations.add(
        '⚠ DNS Resolution Failed: Check your internet connection and DNS settings. '
        'Try using a different DNS server (e.g., 8.8.8.8, 1.1.1.1).',
      );
      // If DNS fails, other tests likely failed too
      return recommendations;
    }

    // Check for WebSocket connectivity issues
    final wsTest = tests.firstWhere(
      (t) => t.name == 'WebSocket Connectivity',
      orElse: () => tests.first,
    );
    if (!wsTest.passed) {
      recommendations.add(
        '⚠ WebSocket Connection Failed: The server may be down or unreachable. '
        'Check your firewall settings and ensure port ${wsTest.details?['port'] ?? 443} is not blocked.',
      );
      return recommendations;
    }

    // Check for authentication issues
    final authTest = tests.firstWhere(
      (t) => t.name == 'SSH Authentication',
      orElse: () => tests.first,
    );
    if (!authTest.passed) {
      recommendations.add(
        '⚠ Authentication Failed: Your credentials may be invalid or expired. '
        'Try logging out and logging back in to refresh your authentication token.',
      );
    }

    // Check for tunnel establishment issues
    final tunnelTest = tests.firstWhere(
      (t) => t.name == 'Tunnel Establishment',
      orElse: () => tests.first,
    );
    if (!tunnelTest.passed) {
      recommendations.add(
        '⚠ Tunnel Establishment Failed: The server may not be responding correctly. '
        'Wait a moment and try again. If the problem persists, contact support.',
      );
    }

    // Check for data transfer issues
    final dataTest = tests.firstWhere(
      (t) => t.name == 'Data Transfer',
      orElse: () => tests.first,
    );
    if (!dataTest.passed) {
      recommendations.add(
        '⚠ Data Transfer Failed: There may be network instability. '
        'Check your connection quality and try again.',
      );
    }

    // Check for latency issues
    final latencyTest = tests.firstWhere(
      (t) => t.name == 'Latency Test',
      orElse: () => tests.first,
    );
    if (!latencyTest.passed) {
      final avgLatency = latencyTest.details?['averageLatency'] ?? 'unknown';
      recommendations.add(
        '⚠ High Latency Detected: Average latency is $avgLatency. '
        'Your connection may be slow. Consider using a wired connection or moving closer to your router.',
      );
    }

    // Check for throughput issues
    final throughputTest = tests.firstWhere(
      (t) => t.name == 'Throughput Test',
      orElse: () => tests.first,
    );
    if (!throughputTest.passed) {
      final throughput = throughputTest.details?['throughput'] ?? 'unknown';
      recommendations.add(
        '⚠ Low Throughput Detected: Transfer rate is $throughput. '
        'Your bandwidth may be limited. Close other applications using the network.',
      );
    }

    // Add general recommendations if multiple tests failed
    if (failedTests.length >= 3) {
      recommendations.add(
        '💡 Multiple tests failed. This suggests a broader connectivity issue. '
        'Try restarting your router or switching to a different network.',
      );
    }

    // If no specific recommendations were added, provide a general one
    if (recommendations.isEmpty) {
      recommendations.add(
        '⚠ Some tests failed. Review the detailed test results above for more information. '
        'Try running diagnostics again in a few moments.',
      );
    }

    return recommendations;
  }

  /// Calculate overall health score (0-100)
  static int calculateHealthScore(DiagnosticReport report) {
    if (report.tests.isEmpty) return 0;

    var score = 0;

    // Base score from pass rate (0-60 points)
    final passRate = report.summary.passRate;
    score += (passRate * 60).round();

    // Bonus points for specific tests (up to 40 points)
    final tests = report.tests;

    // DNS resolution (5 points)
    final dnsTest = tests.firstWhere(
      (t) => t.name == 'DNS Resolution',
      orElse: () => tests.first,
    );
    if (dnsTest.passed) score += 5;

    // WebSocket connectivity (10 points)
    final wsTest = tests.firstWhere(
      (t) => t.name == 'WebSocket Connectivity',
      orElse: () => tests.first,
    );
    if (wsTest.passed) score += 10;

    // Authentication (5 points)
    final authTest = tests.firstWhere(
      (t) => t.name == 'SSH Authentication',
      orElse: () => tests.first,
    );
    if (authTest.passed) score += 5;

    // Tunnel establishment (10 points)
    final tunnelTest = tests.firstWhere(
      (t) => t.name == 'Tunnel Establishment',
      orElse: () => tests.first,
    );
    if (tunnelTest.passed) score += 10;

    // Latency (5 points)
    final latencyTest = tests.firstWhere(
      (t) => t.name == 'Latency Test',
      orElse: () => tests.first,
    );
    if (latencyTest.passed) {
      score += 5;
      // Bonus for excellent latency (< 50ms)
      final avgLatencyStr = latencyTest.details?['averageLatency'] as String?;
      if (avgLatencyStr != null) {
        final avgLatency = int.tryParse(
          avgLatencyStr.replaceAll('ms', ''),
        );
        if (avgLatency != null && avgLatency < 50) {
          score += 3;
        }
      }
    }

    // Throughput (5 points)
    final throughputTest = tests.firstWhere(
      (t) => t.name == 'Throughput Test',
      orElse: () => tests.first,
    );
    if (throughputTest.passed) {
      score += 5;
      // Bonus for excellent throughput (> 500 KB/s)
      final throughputStr = throughputTest.details?['throughput'] as String?;
      if (throughputStr != null) {
        final throughput = double.tryParse(
          throughputStr.replaceAll(' KB/s', ''),
        );
        if (throughput != null && throughput > 500) {
          score += 2;
        }
      }
    }

    return score.clamp(0, 100);
  }

  /// Get health status from score
  static String getHealthStatus(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 50) return 'Fair';
    if (score >= 25) return 'Poor';
    return 'Critical';
  }

  /// Get health status color
  static String getHealthStatusColor(int score) {
    if (score >= 90) return '#4CAF50'; // Green
    if (score >= 75) return '#8BC34A'; // Light Green
    if (score >= 50) return '#FFC107'; // Amber
    if (score >= 25) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  /// Format report as human-readable text
  static String formatReportAsText(DiagnosticReport report) {
    final buffer = StringBuffer();
    final score = calculateHealthScore(report);
    final status = getHealthStatus(score);

    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('           TUNNEL DIAGNOSTIC REPORT');
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Timestamp: ${report.timestamp}');
    buffer.writeln('Health Score: $score/100 ($status)');
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────────────────');
    buffer.writeln('SUMMARY');
    buffer.writeln('───────────────────────────────────────────────────');
    buffer.writeln('Total Tests: ${report.summary.totalTests}');
    buffer.writeln('Passed: ${report.summary.passedTests}');
    buffer.writeln('Failed: ${report.summary.failedTests}');
    buffer.writeln(
      'Pass Rate: ${(report.summary.passRate * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln(
      'Total Duration: ${report.summary.totalDuration.inMilliseconds}ms',
    );
    buffer.writeln();

    buffer.writeln('───────────────────────────────────────────────────');
    buffer.writeln('TEST RESULTS');
    buffer.writeln('───────────────────────────────────────────────────');

    for (final test in report.tests) {
      final status = test.passed ? '✓ PASS' : '✗ FAIL';
      buffer.writeln();
      buffer.writeln('$status - ${test.name}');
      buffer.writeln('  Description: ${test.description}');
      buffer.writeln('  Duration: ${test.duration.inMilliseconds}ms');

      if (!test.passed && test.errorMessage != null) {
        buffer.writeln('  Error: ${test.errorMessage}');
      }

      if (test.details != null && test.details!.isNotEmpty) {
        buffer.writeln('  Details:');
        test.details!.forEach((key, value) {
          buffer.writeln('    - $key: $value');
        });
      }
    }

    buffer.writeln();
    buffer.writeln('───────────────────────────────────────────────────');
    buffer.writeln('RECOMMENDATIONS');
    buffer.writeln('───────────────────────────────────────────────────');

    for (final recommendation in report.summary.recommendations) {
      buffer.writeln();
      buffer.writeln(recommendation);
    }

    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Format report as JSON
  static Map<String, dynamic> formatReportAsJson(DiagnosticReport report) {
    final score = calculateHealthScore(report);
    final status = getHealthStatus(score);

    return {
      'timestamp': report.timestamp.toIso8601String(),
      'healthScore': score,
      'healthStatus': status,
      'summary': report.summary.toJson(),
      'tests': report.tests.map((t) => t.toJson()).toList(),
      'allTestsPassed': report.allTestsPassed,
    };
  }

  /// Format report as Markdown
  static String formatReportAsMarkdown(DiagnosticReport report) {
    final buffer = StringBuffer();
    final score = calculateHealthScore(report);
    final status = getHealthStatus(score);

    buffer.writeln('# Tunnel Diagnostic Report');
    buffer.writeln();
    buffer.writeln('**Timestamp:** ${report.timestamp}');
    buffer.writeln('**Health Score:** $score/100 ($status)');
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('- **Total Tests:** ${report.summary.totalTests}');
    buffer.writeln('- **Passed:** ${report.summary.passedTests}');
    buffer.writeln('- **Failed:** ${report.summary.failedTests}');
    buffer.writeln(
      '- **Pass Rate:** ${(report.summary.passRate * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln(
      '- **Total Duration:** ${report.summary.totalDuration.inMilliseconds}ms',
    );
    buffer.writeln();

    buffer.writeln('## Test Results');
    buffer.writeln();

    for (final test in report.tests) {
      final status = test.passed ? '✓' : '✗';
      buffer.writeln('### $status ${test.name}');
      buffer.writeln();
      buffer.writeln('**Description:** ${test.description}');
      buffer.writeln('**Duration:** ${test.duration.inMilliseconds}ms');
      buffer.writeln('**Status:** ${test.passed ? "PASSED" : "FAILED"}');

      if (!test.passed && test.errorMessage != null) {
        buffer.writeln();
        buffer.writeln('**Error:** ${test.errorMessage}');
      }

      if (test.details != null && test.details!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('**Details:**');
        test.details!.forEach((key, value) {
          buffer.writeln('- **$key:** $value');
        });
      }

      buffer.writeln();
    }

    buffer.writeln('## Recommendations');
    buffer.writeln();

    for (final recommendation in report.summary.recommendations) {
      buffer.writeln('- $recommendation');
    }

    return buffer.toString();
  }
}
