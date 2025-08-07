// CloudToLocalLLM - Service Discovery for Flutter Web on Cloud Run
// This file provides service discovery and configuration for Flutter web app
// when deployed on Google Cloud Run

import 'package:web/web.dart' as web;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
    final hostname = web.window.location.hostname;
    return hostname.contains('.run.app') ||
           hostname.contains('cloudtolocalllm');
  }
  
  /// Load Cloud Run specific configuration
  Future<void> _loadCloudRunConfig() async {
    final hostname = web.window.location.hostname;
    final protocol = web.window.location.protocol;
    
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
    
    // Try to load configuration from JavaScript
    try {
      final configScript = web.document.querySelector('script[data-config="cloudrun"]');
      if (configScript != null) {
        config = jsonDecode(configScript.textContent!);
        _applyConfigOverrides();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CloudToLocalLLM: Could not load JavaScript config: $e');
      }
    }
    
    // Discover actual service URLs
    await _discoverServices();
  }
  
  /// Load development configuration
  void _loadDevelopmentConfig() {
    final protocol = web.window.location.protocol;
    final hostname = web.window.location.hostname;
    final port = web.window.location.port;
    
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
      }
    };
  }
  
  /// Apply configuration overrides from JavaScript
  void _applyConfigOverrides() {
    if (config.containsKey('services')) {
      final services = config['services'] as Map<String, dynamic>;
      
      if (services.containsKey('web') && services['web']['url'] != null) {
        webServiceUrl = services['web']['url'];
      }
      
      if (services.containsKey('api') && services['api']['url'] != null) {
        apiServiceUrl = services['api']['url'];
      }
      
      if (services.containsKey('streaming') && services['streaming']['url'] != null) {
        streamingServiceUrl = services['streaming']['url'];
      }
    }
  }
  
  /// Discover available services
  Future<void> _discoverServices() async {
    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Discovering services...');
    }
    
    final services = {
      'api': apiServiceUrl,
      'streaming': streamingServiceUrl,
    };
    
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
            debugPrint('CloudToLocalLLM: Service $serviceName is ${serviceHealth[serviceName]! ? 'healthy' : 'unhealthy'}');
          }
        } else {
          serviceHealth[serviceName] = false;
          if (kDebugMode) {
            debugPrint('CloudToLocalLLM: Service $serviceName health check failed');
          }
        }
      } catch (e) {
        serviceHealth[serviceName] = false;
        if (kDebugMode) {
          debugPrint('CloudToLocalLLM: Service $serviceName discovery failed: $e');
        }
      }
    }
    
    final healthyServices = serviceHealth.values.where((h) => h).length;
    if (kDebugMode) {
      debugPrint('CloudToLocalLLM: Discovered $healthyServices/${serviceHealth.length} healthy services');
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
  
  /// Make HTTP request with timeout
  Future<Map<String, dynamic>?> _makeRequest(String url, {int timeout = 10}) async {
    try {
      final request = web.XMLHttpRequest();
      request.open('GET', url);
      request.setRequestHeader('Accept', 'application/json');
      
      final completer = Completer<Map<String, dynamic>?>();
      
      request.onLoad.listen((e) {
        if (request.status == 200) {
          try {
            final data = jsonDecode(request.responseText);
            completer.complete(data);
          } catch (e) {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      });
      
      request.onError.listen((e) {
        completer.complete(null);
      });
      
      request.send();
      
      // Add timeout
      Timer(Duration(seconds: timeout), () {
        if (!completer.isCompleted) {
          request.abort();
          completer.complete(null);
        }
      });
      
      return await completer.future;
    } catch (e) {
      return null;
    }
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
    
    web.window.localStorage.setItem(_configKey, jsonEncode(configData));
  }
  
  /// Load configuration from local storage
  bool loadConfig() {
    try {
      final configJson = web.window.localStorage.getItem(_configKey);
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
    web.window.localStorage.removeItem(_configKey);
  }
}
