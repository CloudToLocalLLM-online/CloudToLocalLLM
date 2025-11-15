// CloudToLocalLLM - Service Discovery for Flutter Web on Cloud Run
// This file provides service discovery and configuration for Flutter web app
// when deployed on Google Cloud Run

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

// Conditional imports for web-only functionality
import 'package:cloudtolocalllm/utils/web_interop_stub.dart'
    if (dart.library.js_interop) 'package:cloudtolocalllm/utils/web_interop.dart'
    as html;

class CloudRunConfig {
  static const String _configKey = 'cloudrun_config';
  static CloudRunConfig? _instance;

  // Service URLs
  late String webServiceUrl;
  late String apiServiceUrl;
  late String streamingServiceUrl;

  // Configuration
  late bool isCloudRun;
  late Map<String, dynamic> config;

  // Health check status
  Map<String, bool> serviceHealth = {};
  Timer? _healthCheckTimer;

  CloudRunConfig._();

  static CloudRunConfig get instance {
    _instance ??= CloudRunConfig._();
    return _instance!;
  }

  /// Initialize Cloud Run configuration
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Initializing Cloud Run configuration...');
    }

    // Detect if running on Cloud Run
    isCloudRun = _detectCloudRun();

    if (isCloudRun) {
      if (kDebugMode) {
        debugPrint('CloudToLocalLLM: Running on Cloud Run');
      }
      await _loadCloudRunConfig();
    } else {
      if (kDebugMode) {
        debugPrint('CloudToLocalLLM: Running in development mode');
      }
      _loadDevelopmentConfig();
    }

    // Start health monitoring
    _startHealthMonitoring();

    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Configuration initialized successfully');
      debugPrint('  Web Service: $webServiceUrl');
      debugPrint('  API Service: $apiServiceUrl');
      debugPrint('  Streaming Service: $streamingServiceUrl');
    }
  }

  /// Detect if running on Cloud Run
  bool _detectCloudRun() {
    final href = html.window.location.href;
    return href.contains('.run.app') || href.contains('cloudtolocalllm');
  }

  /// Load Cloud Run specific configuration
  Future<void> _loadCloudRunConfig() async {
    final locationHref = html.window.location.href;
    final uri = Uri.parse(locationHref);
    final hostname = uri.host;
    final protocol = uri.scheme;

    // Determine service URLs based on Cloud Run naming convention
    if (hostname.startsWith('cloudtolocalllm-web')) {
      // We're on the web service, derive other service URLs
      final baseDomain = hostname.replaceFirst('cloudtolocalllm-web', '');
      webServiceUrl = '$protocol//$hostname';
      apiServiceUrl = '$protocol//cloudtolocalllm-api$baseDomain';
      streamingServiceUrl = '$protocol//cloudtolocalllm-streaming$baseDomain';
    } else {
      // Fallback to current domain
      webServiceUrl = '$protocol//$hostname';
      apiServiceUrl = '$protocol//$hostname';
      streamingServiceUrl = '$protocol//$hostname';
    }

    // Configuration loaded from environment or defaults
    config = {
      'environment': 'production',
      'features': {
        'localOllama': false,
        'tunneling': true,
        'streaming': true,
        'auth': true,
      },
    };

    // Discover actual service URLs
    await _discoverServices();
  }

  /// Load development configuration
  void _loadDevelopmentConfig() {
    final locationHref = html.window.location.href;
    final uri = Uri.parse(locationHref);
    final protocol = uri.scheme;
    final hostname = uri.host;
    final port = uri.port.toString();

    webServiceUrl = '$protocol//$hostname:$port';
    apiServiceUrl = '$protocol//$hostname:8080'; // Default API port
    streamingServiceUrl = '$protocol//$hostname:8081'; // Default streaming port

    config = {
      'environment': 'development',
      'features': {
        'localOllama': true,
        'tunneling': false,
        'streaming': true,
        'auth': true,
      },
    };
  }

  /// Discover available services
  Future<void> _discoverServices() async {
    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Discovering services...');
    }

    final services = {'api': apiServiceUrl, 'streaming': streamingServiceUrl};

    for (final entry in services.entries) {
      final serviceName = entry.key;
      final serviceUrl = entry.value;

      try {
        final healthUrl = '$serviceUrl/health';
        if (kDebugMode) {
          debugPrint('CloudToLocalLLM: Checking $serviceName at $healthUrl');
        }

        final response = await _makeRequest(healthUrl, timeout: 5);

        if (response != null && response.containsKey('status')) {
          serviceHealth[serviceName] = response['status'] == 'healthy';
          if (kDebugMode) {
            debugPrint(
              'CloudToLocalLLM: Service $serviceName is ${serviceHealth[serviceName]! ? 'healthy' : 'unhealthy'}',
            );
          }
        } else {
          serviceHealth[serviceName] = false;
          if (kDebugMode) {
            debugPrint(
              'CloudToLocalLLM: Service $serviceName health check failed',
            );
          }
        }
      } catch (e) {
        serviceHealth[serviceName] = false;
        if (kDebugMode) {
          debugPrint(
            'CloudToLocalLLM: Service $serviceName discovery failed: $e',
          );
        }
      }
    }

    final healthyServices = serviceHealth.values.where((h) => h).length;
    if (kDebugMode) {
      debugPrint(
        'CloudToLocalLLM: Discovered $healthyServices/${serviceHealth.length} healthy services',
      );
    }
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _discoverServices();
    });

    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Health monitoring started (30s interval)');
    }
  }

  /// Stop health monitoring
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Health monitoring stopped');
    }
  }

  /// Make HTTP request with timeout (uses package:dio for cross-platform compatibility)
  Future<Map<String, dynamic>?> _makeRequest(
    String url, {
    int timeout = 10,
  }) async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = Duration(seconds: timeout);
      dio.options.receiveTimeout = Duration(seconds: timeout);
      final resp = await dio.get(
        url,
        options: Options(headers: const {'Accept': 'application/json'}),
      );
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return null;
  }

  /// Get API endpoint URL
  String getApiUrl(String endpoint) {
    return '$apiServiceUrl$endpoint';
  }

  /// Get streaming endpoint URL
  String getStreamingUrl(String endpoint) {
    return '$streamingServiceUrl$endpoint';
  }

  /// Check if a feature is enabled
  bool isFeatureEnabled(String feature) {
    if (config.containsKey('features')) {
      final features = config['features'] as Map<String, dynamic>;
      return features[feature] == true;
    }
    return false;
  }

  /// Check if a service is healthy
  bool isServiceHealthy(String service) {
    return serviceHealth[service] == true;
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isCloudRun': isCloudRun,
      'webServiceUrl': webServiceUrl,
      'apiServiceUrl': apiServiceUrl,
      'streamingServiceUrl': streamingServiceUrl,
      'serviceHealth': serviceHealth,
      'features': config['features'] ?? {},
    };
  }

  /// Save configuration to local storage
  void saveConfig() {
    final configData = {
      'webServiceUrl': webServiceUrl,
      'apiServiceUrl': apiServiceUrl,
      'streamingServiceUrl': streamingServiceUrl,
      'isCloudRun': isCloudRun,
      'config': config,
      'timestamp': DateTime.now().toIso8601String(),
    };

    html.window.localStorage.setItem(_configKey, jsonEncode(configData));
  }

  /// Load configuration from local storage
  bool loadConfig() {
    try {
      final configJson = html.window.localStorage.getItem(_configKey);
      if (configJson != null) {
        final configData = jsonDecode(configJson);

        webServiceUrl = configData['webServiceUrl'] ?? '';
        apiServiceUrl = configData['apiServiceUrl'] ?? '';
        streamingServiceUrl = configData['streamingServiceUrl'] ?? '';
        isCloudRun = configData['isCloudRun'] ?? false;
        config = configData['config'] ?? {};

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CloudToLocalLLM: Failed to load saved config: $e');
      }
    }

    return false;
  }

  /// Clear saved configuration
  void clearConfig() {
    html.window.localStorage.removeItem(_configKey);
  }
}
