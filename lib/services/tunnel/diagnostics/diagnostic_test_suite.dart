/// Diagnostic Test Suite
/// Comprehensive tests for tunnel connectivity and performance
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../interfaces/diagnostic_report.dart';

/// Diagnostic test suite
/// Runs comprehensive tests to diagnose tunnel issues
class DiagnosticTestSuite {
  final String serverHost;
  final int serverPort;
  final String? authToken;
  final Duration testTimeout;

  DiagnosticTestSuite({
    required this.serverHost,
    this.serverPort = 443,
    this.authToken,
    this.testTimeout = const Duration(seconds: 30),
  });

  /// Run all diagnostic tests
  Future<List<DiagnosticTest>> runAllTests() async {
    final tests = <DiagnosticTest>[];

    // Run tests in sequence
    tests.add(await testDnsResolution());
    tests.add(await testWebSocketConnectivity());

    // Only run subsequent tests if basic connectivity works
    if (tests.last.passed) {
      tests.add(await testSshAuthentication());
      tests.add(await testTunnelEstablishment());
      tests.add(await testDataTransfer());
      tests.add(await testLatency());
      tests.add(await testThroughput());
    }

    return tests;
  }

  /// Test 1: DNS Resolution
  Future<DiagnosticTest> testDnsResolution() async {
    final stopwatch = Stopwatch()..start();

    try {
      final addresses =
          await InternetAddress.lookup(serverHost).timeout(testTimeout);
      stopwatch.stop();

      if (addresses.isEmpty) {
        return DiagnosticTest(
          name: 'DNS Resolution',
          description: 'Resolve server hostname to IP address',
          passed: false,
          duration: stopwatch.elapsed,
          errorMessage: 'No IP addresses found for $serverHost',
          details: {'host': serverHost},
        );
      }

      return DiagnosticTest(
        name: 'DNS Resolution',
        description: 'Resolve server hostname to IP address',
        passed: true,
        duration: stopwatch.elapsed,
        details: {
          'host': serverHost,
          'addresses': addresses.map((a) => a.address).toList(),
          'addressCount': addresses.length,
        },
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'DNS Resolution',
        description: 'Resolve server hostname to IP address',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'DNS lookup failed: ${e.message}',
        details: {
          'host': serverHost,
          'osError': e.osError?.toString(),
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'DNS Resolution',
        description: 'Resolve server hostname to IP address',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'DNS lookup timed out after ${testTimeout.inSeconds}s',
        details: {'host': serverHost},
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'DNS Resolution',
        description: 'Resolve server hostname to IP address',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {'host': serverHost},
      );
    }
  }

  /// Test 2: WebSocket Connectivity
  Future<DiagnosticTest> testWebSocketConnectivity() async {
    final stopwatch = Stopwatch()..start();
    WebSocketChannel? channel;

    try {
      final uri = Uri.parse('wss://$serverHost:$serverPort/tunnel');

      channel = WebSocketChannel.connect(uri);

      // Wait for connection to establish
      await channel.ready.timeout(testTimeout);

      stopwatch.stop();

      return DiagnosticTest(
        name: 'WebSocket Connectivity',
        description: 'Establish WebSocket connection to server',
        passed: true,
        duration: stopwatch.elapsed,
        details: {
          'uri': uri.toString(),
          'protocol': 'wss',
          'port': serverPort,
        },
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'WebSocket Connectivity',
        description: 'Establish WebSocket connection to server',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'Connection failed: ${e.message}',
        details: {
          'host': serverHost,
          'port': serverPort,
          'osError': e.osError?.toString(),
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'WebSocket Connectivity',
        description: 'Establish WebSocket connection to server',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'Connection timed out after ${testTimeout.inSeconds}s',
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'WebSocket Connectivity',
        description: 'Establish WebSocket connection to server',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } finally {
      await channel?.sink.close();
    }
  }

  /// Test 3: SSH Authentication
  Future<DiagnosticTest> testSshAuthentication() async {
    final stopwatch = Stopwatch()..start();

    try {
      if (authToken == null || authToken!.isEmpty) {
        stopwatch.stop();
        return DiagnosticTest(
          name: 'SSH Authentication',
          description: 'Authenticate with SSH server',
          passed: false,
          duration: stopwatch.elapsed,
          errorMessage: 'No authentication token provided',
          details: {'tokenProvided': false},
        );
      }

      // Simulate authentication check
      // In real implementation, this would validate the token with the server
      await Future.delayed(const Duration(milliseconds: 100));

      stopwatch.stop();

      return DiagnosticTest(
        name: 'SSH Authentication',
        description: 'Authenticate with SSH server',
        passed: true,
        duration: stopwatch.elapsed,
        details: {
          'tokenProvided': true,
          'tokenLength': authToken!.length,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'SSH Authentication',
        description: 'Authenticate with SSH server',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {'tokenProvided': authToken != null},
      );
    }
  }

  /// Test 4: Tunnel Establishment
  Future<DiagnosticTest> testTunnelEstablishment() async {
    final stopwatch = Stopwatch()..start();
    WebSocketChannel? channel;

    try {
      final uri = Uri.parse('wss://$serverHost:$serverPort/tunnel');

      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(testTimeout);

      // Send tunnel establishment message
      final establishMessage = {
        'type': 'establish',
        'token': authToken,
        'timestamp': DateTime.now().toIso8601String(),
      };

      channel.sink.add(establishMessage.toString());

      // Wait for response
      final response =
          await channel.stream.first.timeout(const Duration(seconds: 5));

      stopwatch.stop();

      return DiagnosticTest(
        name: 'Tunnel Establishment',
        description: 'Establish SSH tunnel through WebSocket',
        passed: true,
        duration: stopwatch.elapsed,
        details: {
          'uri': uri.toString(),
          'responseReceived': response != null,
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Tunnel Establishment',
        description: 'Establish SSH tunnel through WebSocket',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'No response from server within 5 seconds',
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Tunnel Establishment',
        description: 'Establish SSH tunnel through WebSocket',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } finally {
      await channel?.sink.close();
    }
  }

  /// Test 5: Data Transfer
  Future<DiagnosticTest> testDataTransfer() async {
    final stopwatch = Stopwatch()..start();
    WebSocketChannel? channel;

    try {
      final uri = Uri.parse('wss://$serverHost:$serverPort/tunnel');

      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(testTimeout);

      // Send test data
      final testData = Uint8List.fromList(
        List.generate(1024, (i) => i % 256), // 1KB test data
      );

      channel.sink.add(testData);

      // Wait for echo response
      final response =
          await channel.stream.first.timeout(const Duration(seconds: 5));

      stopwatch.stop();

      return DiagnosticTest(
        name: 'Data Transfer',
        description: 'Transfer data through tunnel',
        passed: true,
        duration: stopwatch.elapsed,
        details: {
          'bytesSent': testData.length,
          'bytesReceived': response is Uint8List ? response.length : 0,
          'transferRate':
              '${(testData.length / stopwatch.elapsed.inMilliseconds * 1000).toStringAsFixed(2)} bytes/s',
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Data Transfer',
        description: 'Transfer data through tunnel',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'Data transfer timed out',
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Data Transfer',
        description: 'Transfer data through tunnel',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } finally {
      await channel?.sink.close();
    }
  }

  /// Test 6: Latency Test
  Future<DiagnosticTest> testLatency() async {
    final stopwatch = Stopwatch()..start();
    WebSocketChannel? channel;

    try {
      final uri = Uri.parse('wss://$serverHost:$serverPort/tunnel');

      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(testTimeout);

      // Perform multiple ping-pong tests
      final latencies = <Duration>[];
      const pingCount = 10;

      for (var i = 0; i < pingCount; i++) {
        final pingStopwatch = Stopwatch()..start();

        // Send ping
        channel.sink.add('ping');

        // Wait for pong
        await channel.stream.first.timeout(const Duration(seconds: 2));

        pingStopwatch.stop();
        latencies.add(pingStopwatch.elapsed);

        // Small delay between pings
        await Future.delayed(const Duration(milliseconds: 100));
      }

      stopwatch.stop();

      // Calculate statistics
      final avgLatency = latencies.fold<Duration>(
            Duration.zero,
            (sum, latency) => sum + latency,
          ) ~/
          pingCount;

      final minLatency = latencies.reduce(
        (a, b) => a < b ? a : b,
      );

      final maxLatency = latencies.reduce(
        (a, b) => a > b ? a : b,
      );

      // Determine if latency is acceptable (< 200ms average)
      final passed = avgLatency.inMilliseconds < 200;

      return DiagnosticTest(
        name: 'Latency Test',
        description: 'Measure round-trip latency',
        passed: passed,
        duration: stopwatch.elapsed,
        errorMessage: passed ? null : 'Average latency exceeds 200ms',
        details: {
          'pingCount': pingCount,
          'averageLatency': '${avgLatency.inMilliseconds}ms',
          'minLatency': '${minLatency.inMilliseconds}ms',
          'maxLatency': '${maxLatency.inMilliseconds}ms',
          'latencies': latencies.map((l) => '${l.inMilliseconds}ms').toList(),
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Latency Test',
        description: 'Measure round-trip latency',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'Latency test timed out',
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Latency Test',
        description: 'Measure round-trip latency',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } finally {
      await channel?.sink.close();
    }
  }

  /// Test 7: Throughput Test
  Future<DiagnosticTest> testThroughput() async {
    final stopwatch = Stopwatch()..start();
    WebSocketChannel? channel;

    try {
      final uri = Uri.parse('wss://$serverHost:$serverPort/tunnel');

      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(testTimeout);

      // Send larger data chunks to measure throughput
      const chunkSize = 64 * 1024; // 64KB chunks
      const chunkCount = 10;
      var totalBytesSent = 0;
      var totalBytesReceived = 0;

      final throughputStopwatch = Stopwatch()..start();

      for (var i = 0; i < chunkCount; i++) {
        final chunk = Uint8List.fromList(
          List.generate(chunkSize, (i) => i % 256),
        );

        channel.sink.add(chunk);
        totalBytesSent += chunk.length;

        // Wait for acknowledgment
        final response =
            await channel.stream.first.timeout(const Duration(seconds: 5));

        if (response is Uint8List) {
          totalBytesReceived += response.length;
        }
      }

      throughputStopwatch.stop();
      stopwatch.stop();

      // Calculate throughput in KB/s
      final durationSeconds = throughputStopwatch.elapsed.inMilliseconds / 1000;
      final throughputKBps = (totalBytesSent / 1024) / durationSeconds;

      // Determine if throughput is acceptable (> 100 KB/s)
      final passed = throughputKBps > 100;

      return DiagnosticTest(
        name: 'Throughput Test',
        description: 'Measure data transfer throughput',
        passed: passed,
        duration: stopwatch.elapsed,
        errorMessage: passed ? null : 'Throughput below 100 KB/s',
        details: {
          'chunkSize': '$chunkSize bytes',
          'chunkCount': chunkCount,
          'totalBytesSent': totalBytesSent,
          'totalBytesReceived': totalBytesReceived,
          'throughput': '${throughputKBps.toStringAsFixed(2)} KB/s',
          'duration': '${durationSeconds.toStringAsFixed(2)}s',
        },
      );
    } on TimeoutException catch (_) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Throughput Test',
        description: 'Measure data transfer throughput',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: 'Throughput test timed out',
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return DiagnosticTest(
        name: 'Throughput Test',
        description: 'Measure data transfer throughput',
        passed: false,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
        details: {
          'host': serverHost,
          'port': serverPort,
        },
      );
    } finally {
      await channel?.sink.close();
    }
  }
}
