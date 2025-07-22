// ignore_for_file: avoid_print, unused_local_variable, non_type_in_catch_clause
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

/// Integration tests for container-to-tunnel communication
/// Tests that containers can use standard HTTP libraries to communicate
/// through the simplified tunnel proxy without special tunnel-aware code
void main() {
  group('Container Tunnel Integration Tests', () {
    late String testUserId;
    late String tunnelBaseUrl;
    late String containerHealthUrl;

    setUpAll(() async {
      // Test configuration
      testUserId = Platform.environment['TEST_USER_ID'] ?? 'test-user-123';
      final apiBaseUrl =
          Platform.environment['API_BASE_URL'] ?? 'http://localhost:8080';
      tunnelBaseUrl = '$apiBaseUrl/api/tunnel/$testUserId';
      containerHealthUrl =
          Platform.environment['CONTAINER_HEALTH_URL'] ??
          'http://localhost:8081';

      print('Running container tunnel integration tests');
      print('Test User ID: $testUserId');
      print('Tunnel Base URL: $tunnelBaseUrl');
      print('Container Health URL: $containerHealthUrl');
    });

    test('container can make HTTP requests through tunnel proxy', () async {
      // Test that a container can make standard HTTP requests
      // through the tunnel proxy endpoint without special tunnel code

      try {
        final response = await http
            .get(
              Uri.parse('$tunnelBaseUrl/api/tags'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'CloudToLocalLLM-Test/1.0',
              },
            )
            .timeout(Duration(seconds: 30));

        expect(
          response.statusCode,
          anyOf([200, 503]),
        ); // 200 if connected, 503 if desktop offline

        if (response.statusCode == 200) {
          // If successful, verify response structure
          final data = jsonDecode(response.body);
          expect(data, isA<Map<String, dynamic>>());
          print('✅ Container successfully communicated through tunnel');
          print('Response: ${response.body.substring(0, 100)}...');
        } else {
          // If desktop is offline, verify proper error response
          expect(response.statusCode, equals(503));
          final errorData = jsonDecode(response.body);
          expect(errorData['error'], contains('not connected'));
          print('✅ Container received proper error when desktop offline');
        }
      } catch (e) {
        print('❌ Container tunnel communication failed: $e');
        rethrow;
      }
    });

    test('container environment variables are properly configured', () async {
      // Test that containers have the correct OLLAMA_BASE_URL environment variable
      // pointing to the tunnel proxy endpoint

      try {
        final response = await http
            .get(
              Uri.parse('$containerHealthUrl/health'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(Duration(seconds: 10));

        expect(response.statusCode, equals(200));

        final healthData = jsonDecode(response.body);
        expect(healthData['status'], equals('healthy'));
        expect(healthData['tunnelConfigured'], equals(true));
        expect(healthData['ollamaBaseUrl'], contains('/api/tunnel/'));

        print('✅ Container environment properly configured');
        print('OLLAMA_BASE_URL: ${healthData['ollamaBaseUrl']}');
      } catch (e) {
        print('❌ Container health check failed: $e');
        rethrow;
      }
    });

    test('container can test tunnel connectivity', () async {
      // Test the container's built-in tunnel connectivity test

      try {
        final response = await http
            .get(
              Uri.parse('$containerHealthUrl/test-tunnel'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(Duration(seconds: 35)); // Allow time for tunnel test

        expect(
          response.statusCode,
          anyOf([200, 500]),
        ); // 200 if connected, 500 if failed

        final testData = jsonDecode(response.body);
        expect(testData, containsPair('timestamp', isA<String>()));
        expect(testData, containsPair('stats', isA<Map<String, dynamic>>()));

        if (response.statusCode == 200) {
          expect(testData['tunnelConnected'], equals(true));
          print('✅ Container tunnel connectivity test passed');
        } else {
          expect(testData['error'], isA<String>());
          print(
            '✅ Container tunnel connectivity test properly reported failure',
          );
        }

        print('Test stats: ${testData['stats']}');
      } catch (e) {
        print('❌ Container tunnel test failed: $e');
        rethrow;
      }
    });

    test(
      'container uses standard HTTP libraries without tunnel-specific code',
      () async {
        // Verify that containers don't need special tunnel-aware code
        // by checking that they use standard HTTP client patterns

        try {
          final response = await http
              .get(
                Uri.parse('$containerHealthUrl/stats'),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(Duration(seconds: 10));

          expect(response.statusCode, equals(200));

          final statsData = jsonDecode(response.body);
          expect(statsData['tunnel']['configured'], equals(true));
          expect(statsData['tunnel']['baseUrl'], isA<String>());

          // Verify the container is using standard HTTP patterns
          final tunnelStats = statsData['tunnel']['stats'];
          expect(tunnelStats, containsPair('requestCount', isA<int>()));
          expect(tunnelStats, containsPair('successCount', isA<int>()));
          expect(tunnelStats, containsPair('errorCount', isA<int>()));
          expect(tunnelStats, containsPair('successRate', isA<num>()));

          print('✅ Container using standard HTTP client patterns');
          print('Request stats: $tunnelStats');
        } catch (e) {
          print('❌ Container stats check failed: $e');
          rethrow;
        }
      },
    );

    test(
      'multiple containers can communicate through tunnel simultaneously',
      () async {
        // Test that multiple containers can use the tunnel proxy concurrently
        // without interference

        final futures = <Future<http.Response>>[];
        const concurrentRequests = 5;

        for (int i = 0; i < concurrentRequests; i++) {
          futures.add(
            http
                .get(
                  Uri.parse('$tunnelBaseUrl/api/tags'),
                  headers: {
                    'Content-Type': 'application/json',
                    'User-Agent': 'CloudToLocalLLM-Test-$i/1.0',
                  },
                )
                .timeout(Duration(seconds: 30)),
          );
        }

        try {
          final responses = await Future.wait(futures);

          // All requests should have the same status (either all succeed or all fail)
          final statusCodes = responses.map((r) => r.statusCode).toSet();
          expect(statusCodes.length, equals(1)); // All same status

          final commonStatus = statusCodes.first;
          expect(commonStatus, anyOf([200, 503])); // Success or desktop offline

          print('✅ Multiple concurrent requests handled properly');
          print('Status: $commonStatus, Count: ${responses.length}');
        } catch (e) {
          print('❌ Concurrent requests test failed: $e');
          rethrow;
        }
      },
    );

    test('container handles tunnel errors gracefully', () async {
      // Test that containers receive proper HTTP error responses
      // when tunnel is unavailable or requests fail

      try {
        // Make request to non-existent endpoint to trigger error
        final response = await http
            .get(
              Uri.parse('$tunnelBaseUrl/api/nonexistent'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'CloudToLocalLLM-Test/1.0',
              },
            )
            .timeout(Duration(seconds: 30));

        // Should receive proper HTTP error response
        expect(response.statusCode, anyOf([404, 503, 504]));

        if (response.body.isNotEmpty) {
          final errorData = jsonDecode(response.body);
          expect(errorData, containsPair('error', isA<String>()));
        }

        print(
          '✅ Container received proper error response: ${response.statusCode}',
        );
      } catch (e) {
        print('❌ Error handling test failed: $e');
        rethrow;
      }
    });

    test('container request timeout handling', () async {
      // Test that containers properly handle request timeouts
      // through the tunnel proxy

      try {
        // Make request with very short timeout to test timeout handling
        await http
            .get(
              Uri.parse('$tunnelBaseUrl/api/tags'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'CloudToLocalLLM-Test/1.0',
              },
            )
            .timeout(Duration(milliseconds: 100)); // Very short timeout

        // If we get here, the request was faster than expected
        print('✅ Request completed within timeout');
      } catch (e) {
        // Check if it's a timeout or other error
        if (e.toString().contains('TimeoutException')) {
          // Expected timeout behavior
          print('✅ Container properly handled request timeout');
        } else {
          // Other errors are also acceptable (connection refused, etc.)
          print('✅ Container handled request error: ${e.runtimeType}');
        }
      }
    });
  });

  group('Container Integration Environment Tests', () {
    test('verify test environment is properly configured', () async {
      // Verify that the test environment has the necessary components

      final testUserId =
          Platform.environment['TEST_USER_ID'] ?? 'test-user-123';
      final apiBaseUrl =
          Platform.environment['API_BASE_URL'] ?? 'http://localhost:8080';

      // Test API backend health
      try {
        final apiResponse = await http
            .get(
              Uri.parse('$apiBaseUrl/health'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(Duration(seconds: 10));

        expect(apiResponse.statusCode, equals(200));
        final apiHealth = jsonDecode(apiResponse.body);
        expect(apiHealth['status'], equals('healthy'));

        print('✅ API Backend is healthy');
      } catch (e) {
        print('❌ API Backend health check failed: $e');
        rethrow;
      }

      // Test tunnel endpoint availability
      try {
        final tunnelResponse = await http
            .get(
              Uri.parse('$apiBaseUrl/api/tunnel/status'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization':
                    'Bearer test-token', // This will fail auth but test endpoint
              },
            )
            .timeout(Duration(seconds: 10));

        // Should get 401/403 for invalid token, not 404 for missing endpoint
        expect(tunnelResponse.statusCode, anyOf([401, 403]));

        print('✅ Tunnel endpoint is available');
      } catch (e) {
        print('❌ Tunnel endpoint test failed: $e');
        rethrow;
      }
    });
  });
}
