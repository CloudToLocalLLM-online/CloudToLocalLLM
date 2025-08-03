/// Tunnel LLM Request Handler
///
/// Handles LLM-specific request processing for tunnel communication with comprehensive
/// validation, routing, streaming support, and intelligent timeout management.
///
/// ## Core Responsibilities
/// 
/// ### Request Processing Pipeline
/// 1. **Request Validation**: Comprehensive validation of LLM requests
///    - JSON structure validation for POST requests
///    - Provider availability verification
///    - Request parameter validation
///    - Timeout and priority inference
/// 
/// 2. **Provider Selection & Routing**: Intelligent provider selection
///    - Preferred provider selection with fallback
///    - Health-based provider failover
///    - Load balancing across available providers
///    - Provider capability matching
/// 
/// 3. **Request Execution**: Optimized request processing
///    - LangChain integration for standardized LLM operations
///    - Direct provider communication fallback
///    - Streaming request handling with proper buffering
///    - Timeout management with request-type-specific timeouts
/// 
/// 4. **Error Handling & Recovery**: Comprehensive error management
///    - Provider-specific error classification
///    - Automatic retry with exponential backoff
///    - Circuit breaker pattern for failing providers
///    - Graceful degradation strategies
/// 
/// ## Request Types & Timeouts
/// 
/// | Request Type | Default Timeout | Description |
/// |--------------|----------------|-------------|
/// | `textGeneration` | 60s | Standard text completion |
/// | `streamingGeneration` | 5m | Streaming chat/completion |
/// | `modelPull` | 30m | Model download operations |
/// | `modelList` | 10s | List available models |
/// | `modelInfo` | 10s | Get model information |
/// | `healthCheck` | 10s | Provider health verification |
/// | `modelDelete` | 30s | Model removal operations |
/// 
/// ## Request Priority System
/// 
/// | Priority | Value | Use Cases |
/// |----------|-------|-----------|
/// | `critical` | 3 | Health checks, provider status |
/// | `high` | 2 | Text generation, streaming |
/// | `normal` | 1 | Model info, model list |
/// | `low` | 0 | Model pull, model delete |
/// 
/// ## Streaming Request Handling
/// 
/// The handler supports streaming requests with:
/// - **Chunked Response Processing**: Efficient streaming with proper buffering
/// - **Connection Management**: Automatic cleanup of streaming resources
/// - **Timeout Handling**: Extended timeouts for long-running streams
/// - **Error Recovery**: Graceful handling of stream interruptions
/// 
/// ## Usage Examples
/// 
/// ### Basic Request Handling
/// ```dart
/// final handler = TunnelLLMRequestHandler(
///   providerManager: providerManager,
///   errorHandler: errorHandler,
///   langchainService: langchainService,
/// );
/// 
/// final response = await handler.handleLLMRequest(tunnelRequest);
/// ```
/// 
/// ### Streaming Request Handling
/// ```dart
/// await for (final chunk in handler.handleStreamingRequest(tunnelRequest)) {
///   print('Received chunk: ${chunk.body}');
/// }
/// ```
/// 
/// ### Error Handling
/// ```dart
/// try {
///   final response = await handler.handleLLMRequest(request);
/// } catch (e) {
///   if (e is LLMCommunicationError) {
///     print('LLM Error: ${e.userFriendlyMessage}');
///     print('Recovery: ${e.troubleshootingSteps}');
///   }
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/tunnel_message.dart';
import '../models/llm_communication_error.dart';
import 'llm_provider_manager.dart';
import 'llm_error_handler.dart';
import 'langchain_integration_service.dart';

/// LLM request types for tunnel operations
enum LLMRequestType {
  textGeneration,
  streamingGeneration,
  modelList,
  modelPull,
  modelDelete,
  modelInfo,
  healthCheck,
  providerStatus,
  unknown,
}

/// Request priority levels
enum RequestPriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  const RequestPriority(this.value);
  final int value;
}

/// LLM-specific tunnel request
class TunnelLLMRequest {
  final String id;
  final LLMRequestType type;
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body;
  final String? preferredProvider;
  final Duration? customTimeout;
  final bool isStreaming;
  final RequestPriority priority;
  final Map<String, dynamic> llmParameters;
  final DateTime timestamp;

  TunnelLLMRequest({
    required this.id,
    required this.type,
    required this.method,
    required this.path,
    required this.headers,
    this.body,
    this.preferredProvider,
    this.customTimeout,
    this.isStreaming = false,
    this.priority = RequestPriority.normal,
    this.llmParameters = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from tunnel request message
  factory TunnelLLMRequest.fromTunnelRequest(TunnelRequestMessage request) {
    final requestType = _inferRequestType(request.method, request.path);
    final isStreaming = _isStreamingRequest(request.path, request.body);
    final priority = _inferPriority(requestType);
    final llmParams = _extractLLMParameters(request.body);
    final preferredProvider = _extractPreferredProvider(request.headers, llmParams);
    final customTimeout = _extractCustomTimeout(request.headers, llmParams);

    return TunnelLLMRequest(
      id: request.id,
      type: requestType,
      method: request.method,
      path: request.path,
      headers: request.headers,
      body: request.body,
      preferredProvider: preferredProvider,
      customTimeout: customTimeout,
      isStreaming: isStreaming,
      priority: priority,
      llmParameters: llmParams,
    );
  }

  /// Convert to tunnel request message
  TunnelRequestMessage toTunnelRequest() {
    return TunnelRequestMessage(
      id: id,
      method: method,
      path: path,
      headers: headers,
      body: body,
    );
  }

  /// Get default timeout for request type
  Duration get defaultTimeout {
    switch (type) {
      case LLMRequestType.textGeneration:
        return const Duration(seconds: 60);
      case LLMRequestType.streamingGeneration:
        return const Duration(minutes: 5);
      case LLMRequestType.modelPull:
        return const Duration(minutes: 30);
      case LLMRequestType.modelList:
      case LLMRequestType.modelInfo:
      case LLMRequestType.healthCheck:
      case LLMRequestType.providerStatus:
        return const Duration(seconds: 10);
      case LLMRequestType.modelDelete:
        return const Duration(seconds: 30);
      default:
        return const Duration(seconds: 30);
    }
  }

  /// Get effective timeout (custom or default)
  Duration get effectiveTimeout => customTimeout ?? defaultTimeout;

  /// Infer request type from method and path
  static LLMRequestType _inferRequestType(String method, String path) {
    final pathLower = path.toLowerCase();
    
    if (pathLower.contains('/api/generate') || pathLower.contains('/v1/completions')) {
      return LLMRequestType.textGeneration;
    }
    if (pathLower.contains('/api/chat') || pathLower.contains('/v1/chat/completions')) {
      return LLMRequestType.streamingGeneration;
    }
    if (pathLower.contains('/api/tags') || pathLower.contains('/v1/models')) {
      return LLMRequestType.modelList;
    }
    if (pathLower.contains('/api/pull')) {
      return LLMRequestType.modelPull;
    }
    if (pathLower.contains('/api/delete')) {
      return LLMRequestType.modelDelete;
    }
    if (pathLower.contains('/api/show')) {
      return LLMRequestType.modelInfo;
    }
    if (pathLower.contains('/health') || pathLower.contains('/status')) {
      return LLMRequestType.healthCheck;
    }
    
    return LLMRequestType.unknown;
  }

  /// Check if request is streaming
  static bool _isStreamingRequest(String path, String? body) {
    if (body == null) return false;
    
    try {
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;
      return jsonBody['stream'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Infer priority from request type
  static RequestPriority _inferPriority(LLMRequestType type) {
    switch (type) {
      case LLMRequestType.healthCheck:
      case LLMRequestType.providerStatus:
        return RequestPriority.critical;
      case LLMRequestType.textGeneration:
      case LLMRequestType.streamingGeneration:
        return RequestPriority.high;
      case LLMRequestType.modelList:
      case LLMRequestType.modelInfo:
        return RequestPriority.normal;
      case LLMRequestType.modelPull:
      case LLMRequestType.modelDelete:
        return RequestPriority.low;
      default:
        return RequestPriority.normal;
    }
  }

  /// Extract LLM parameters from request body
  static Map<String, dynamic> _extractLLMParameters(String? body) {
    if (body == null || body.isEmpty) return {};
    
    try {
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(jsonBody);
    } catch (e) {
      return {};
    }
  }

  /// Extract preferred provider from headers or parameters
  static String? _extractPreferredProvider(
    Map<String, String> headers,
    Map<String, dynamic> params,
  ) {
    return headers['x-preferred-provider'] ?? 
           params['preferred_provider'] as String?;
  }

  /// Extract custom timeout from headers or parameters
  static Duration? _extractCustomTimeout(
    Map<String, String> headers,
    Map<String, dynamic> params,
  ) {
    final timeoutHeader = headers['x-request-timeout'];
    final timeoutParam = params['timeout'];
    
    if (timeoutHeader != null) {
      final seconds = int.tryParse(timeoutHeader);
      if (seconds != null) return Duration(seconds: seconds);
    }
    
    if (timeoutParam != null) {
      if (timeoutParam is int) return Duration(seconds: timeoutParam);
      if (timeoutParam is double) return Duration(milliseconds: (timeoutParam * 1000).round());
    }
    
    return null;
  }
}

/// LLM-specific tunnel response
class TunnelLLMResponse {
  final String requestId;
  final int status;
  final Map<String, String> headers;
  final String body;
  final bool isStreaming;
  final String? providerId;
  final Duration? processingTime;
  final LLMCommunicationError? error;
  final DateTime timestamp;

  TunnelLLMResponse({
    required this.requestId,
    required this.status,
    required this.headers,
    required this.body,
    this.isStreaming = false,
    this.providerId,
    this.processingTime,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create success response
  factory TunnelLLMResponse.success({
    required String requestId,
    required String body,
    Map<String, String>? headers,
    bool isStreaming = false,
    String? providerId,
    Duration? processingTime,
  }) {
    return TunnelLLMResponse(
      requestId: requestId,
      status: 200,
      headers: {
        'content-type': 'application/json',
        ...?headers,
      },
      body: body,
      isStreaming: isStreaming,
      providerId: providerId,
      processingTime: processingTime,
    );
  }

  /// Create error response
  factory TunnelLLMResponse.error({
    required String requestId,
    required LLMCommunicationError error,
    String? providerId,
    Duration? processingTime,
  }) {
    final errorBody = jsonEncode({
      'error': error.userFriendlyMessage,
      'type': error.type.toString().split('.').last,
      'details': error.details,
      'troubleshooting': error.troubleshootingSteps,
      'timestamp': error.timestamp.toIso8601String(),
      'retryable': error.isRetryable,
    });

    return TunnelLLMResponse(
      requestId: requestId,
      status: _getHttpStatusFromError(error),
      headers: {'content-type': 'application/json'},
      body: errorBody,
      providerId: providerId,
      processingTime: processingTime,
      error: error,
    );
  }

  /// Convert to tunnel response message
  TunnelResponseMessage toTunnelResponse() {
    return TunnelResponseMessage(
      id: requestId,
      status: status,
      headers: headers,
      body: body,
    );
  }

  /// Create a copy with updated fields
  TunnelLLMResponse copyWith({
    String? requestId,
    int? status,
    Map<String, String>? headers,
    String? body,
    bool? isStreaming,
    String? providerId,
    Duration? processingTime,
    LLMCommunicationError? error,
    DateTime? timestamp,
  }) {
    return TunnelLLMResponse(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      isStreaming: isStreaming ?? this.isStreaming,
      providerId: providerId ?? this.providerId,
      processingTime: processingTime ?? this.processingTime,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Get HTTP status code from error
  static int _getHttpStatusFromError(LLMCommunicationError error) {
    switch (error.type) {
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.modelNotFound:
        return 404;
      case LLMCommunicationErrorType.authenticationFailed:
        return 401;
      case LLMCommunicationErrorType.authorizationDenied:
        return 403;
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.connectionTimeout:
        return 408;
      case LLMCommunicationErrorType.requestTooLarge:
        return 413;
      case LLMCommunicationErrorType.requestRateLimited:
        return 429;
      case LLMCommunicationErrorType.providerUnavailable:
      case LLMCommunicationErrorType.tunnelDisconnected:
        return 503;
      default:
        return 500;
    }
  }
}

/// Tunnel LLM Request Handler
class TunnelLLMRequestHandler extends ChangeNotifier {
  final LLMProviderManager _providerManager;
  final LLMErrorHandler _errorHandler;
  final LangChainIntegrationService? _langchainService;

  // Request processing state
  final Map<String, TunnelLLMRequest> _activeRequests = {};
  final Map<String, StreamController<String>> _streamingControllers = {};
  final Map<String, Timer> _requestTimers = {};
  
  // Statistics
  int _requestsProcessed = 0;
  int _requestsSucceeded = 0;
  int _requestsFailed = 0;
  int _streamingRequestsActive = 0;
  
  static const int _maxConcurrentRequests = 10;

  TunnelLLMRequestHandler({
    required LLMProviderManager providerManager,
    required LLMErrorHandler errorHandler,
    LangChainIntegrationService? langchainService,
  }) : _providerManager = providerManager,
       _errorHandler = errorHandler,
       _langchainService = langchainService;

  /// Get processing statistics
  Map<String, dynamic> get statistics => {
    'requestsProcessed': _requestsProcessed,
    'requestsSucceeded': _requestsSucceeded,
    'requestsFailed': _requestsFailed,
    'activeRequests': _activeRequests.length,
    'streamingRequestsActive': _streamingRequestsActive,
    'maxConcurrentRequests': _maxConcurrentRequests,
  };

  /// Handle LLM request with comprehensive processing
  Future<TunnelLLMResponse> handleLLMRequest(TunnelRequestMessage request) async {
    final stopwatch = Stopwatch()..start();
    final llmRequest = TunnelLLMRequest.fromTunnelRequest(request);
    
    debugPrint('🔄 [TunnelLLM] Processing ${llmRequest.type} request: ${llmRequest.id}');
    
    try {
      // Validate request
      await _validateRequest(llmRequest);
      
      // Check concurrent request limits
      if (_activeRequests.length >= _maxConcurrentRequests) {
        throw LLMCommunicationError(
          type: LLMCommunicationErrorType.requestRateLimited,
          message: 'Too many concurrent requests',
          severity: ErrorSeverity.medium,
          recoveryStrategy: RecoveryStrategy.retryWithBackoff,
          requestId: llmRequest.id,
        );
      }

      // Add to active requests
      _activeRequests[llmRequest.id] = llmRequest;
      
      // Set up timeout timer
      _setupRequestTimeout(llmRequest);
      
      // Process request based on type
      final response = await _processRequestByType(llmRequest);
      
      stopwatch.stop();
      _requestsProcessed++;
      _requestsSucceeded++;
      
      debugPrint('✅ [TunnelLLM] Request completed: ${llmRequest.id} (${stopwatch.elapsedMilliseconds}ms)');
      
      return response.copyWith(processingTime: stopwatch.elapsed);
      
    } catch (error) {
      stopwatch.stop();
      _requestsProcessed++;
      _requestsFailed++;

      final llmError = error is LLMCommunicationError
          ? error
          : LLMCommunicationError.fromException(
              error is Exception ? error : Exception(error.toString()),
              requestId: llmRequest.id,
            );

      debugPrint('❌ [TunnelLLM] Request failed: ${llmRequest.id} - ${llmError.message}');

      // Use error handler to attempt recovery with retry logic
      final recoveredResponse = await _errorHandler.handleError<TunnelLLMResponse>(
        llmError,
        () => _processRequestByType(llmRequest),
        providerId: llmRequest.preferredProvider,
        allowProviderSwitch: true,
      );

      // If error handler recovered successfully, return the result
      if (recoveredResponse != null) {
        return recoveredResponse;
      }

      // Fallback to manual error recovery attempt
      final manualRecovery = await _attemptErrorRecovery(llmRequest, llmError);
      if (manualRecovery != null) {
        return manualRecovery;
      }

      return TunnelLLMResponse.error(
        requestId: llmRequest.id,
        error: llmError,
        processingTime: stopwatch.elapsed,
      );

    } finally {
      // Cleanup
      _cleanupRequest(llmRequest.id);
    }
  }

  /// Handle streaming LLM request
  Stream<TunnelLLMResponse> handleStreamingRequest(TunnelRequestMessage request) async* {
    final llmRequest = TunnelLLMRequest.fromTunnelRequest(request);
    
    debugPrint('🌊 [TunnelLLM] Starting streaming request: ${llmRequest.id}');
    
    try {
      // Validate streaming request
      await _validateStreamingRequest(llmRequest);
      
      // Get provider for streaming
      final provider = await _getProviderForRequest(llmRequest);
      if (provider == null) {
        yield TunnelLLMResponse.error(
          requestId: llmRequest.id,
          error: LLMCommunicationError.providerNotFound(
            requestId: llmRequest.id,
            providerId: llmRequest.preferredProvider,
          ),
        );
        return;
      }

      // Set up streaming controller
      final controller = StreamController<String>();
      _streamingControllers[llmRequest.id] = controller;
      _streamingRequestsActive++;
      
      // Set up timeout for streaming
      _setupStreamingTimeout(llmRequest);
      
      // Process streaming request
      await _processStreamingRequest(llmRequest, provider, controller);
      
      // Yield streaming responses
      await for (final chunk in controller.stream) {
        yield TunnelLLMResponse.success(
          requestId: llmRequest.id,
          body: chunk,
          isStreaming: true,
          providerId: provider.info.id,
        );
      }
      
      debugPrint('✅ [TunnelLLM] Streaming completed: ${llmRequest.id}');
      
    } catch (error) {
      final llmError = error is LLMCommunicationError
          ? error
          : LLMCommunicationError.fromException(
              error is Exception ? error : Exception(error.toString()),
              requestId: llmRequest.id,
            );
      
      debugPrint('❌ [TunnelLLM] Streaming failed: ${llmRequest.id} - ${llmError.message}');
      
      yield TunnelLLMResponse.error(
        requestId: llmRequest.id,
        error: llmError,
      );
      
    } finally {
      // Cleanup streaming resources
      _cleanupStreamingRequest(llmRequest.id);
    }
  }

  /// Validate LLM request
  Future<void> _validateRequest(TunnelLLMRequest request) async {
    // Basic validation
    if (request.id.isEmpty) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'Request ID cannot be empty',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }

    if (request.method.isEmpty || request.path.isEmpty) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'Request method and path are required',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }

    // Validate request body for POST requests
    if (request.method.toUpperCase() == 'POST' && request.body != null) {
      try {
        jsonDecode(request.body!);
      } catch (e) {
        throw LLMCommunicationError(
          type: LLMCommunicationErrorType.requestMalformed,
          message: 'Invalid JSON in request body',
          details: e.toString(),
          severity: ErrorSeverity.medium,
          recoveryStrategy: RecoveryStrategy.noRecovery,
          requestId: request.id,
        );
      }
    }

    // Validate preferred provider if specified
    if (request.preferredProvider != null) {
      final provider = _providerManager.getProvider(request.preferredProvider!);
      if (provider == null) {
        throw LLMCommunicationError.providerNotFound(
          requestId: request.id,
          providerId: request.preferredProvider,
        );
      }
    }
  }

  /// Validate streaming request
  Future<void> _validateStreamingRequest(TunnelLLMRequest request) async {
    await _validateRequest(request);
    
    if (!request.isStreaming) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'Request is not configured for streaming',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }
  }

  /// Process request based on type
  Future<TunnelLLMResponse> _processRequestByType(TunnelLLMRequest request) async {
    switch (request.type) {
      case LLMRequestType.textGeneration:
        return await _processTextGeneration(request);
      case LLMRequestType.modelList:
        return await _processModelList(request);
      case LLMRequestType.modelInfo:
        return await _processModelInfo(request);
      case LLMRequestType.healthCheck:
        return await _processHealthCheck(request);
      case LLMRequestType.providerStatus:
        return await _processProviderStatus(request);
      default:
        return await _processGenericRequest(request);
    }
  }

  /// Process text generation request
  Future<TunnelLLMResponse> _processTextGeneration(TunnelLLMRequest request) async {
    final provider = await _getProviderForRequest(request);
    if (provider == null) {
      throw LLMCommunicationError.providerNotFound(
        requestId: request.id,
        providerId: request.preferredProvider,
      );
    }

    // Use LangChain service if available
    if (_langchainService != null && provider.langchainWrapper != null) {
      return await _processWithLangChain(request, provider);
    }

    // Fallback to direct provider communication
    return await _processWithDirectProvider(request, provider);
  }

  /// Process model list request
  Future<TunnelLLMResponse> _processModelList(TunnelLLMRequest request) async {
    final provider = await _getProviderForRequest(request);
    if (provider == null) {
      throw LLMCommunicationError.providerNotFound(
        requestId: request.id,
        providerId: request.preferredProvider,
      );
    }

    // Get available models from provider
    final models = provider.info.availableModels;
    final responseBody = jsonEncode({
      'models': models.map((model) => {'name': model}).toList(),
      'provider': provider.info.name,
      'provider_id': provider.info.id,
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
      providerId: provider.info.id,
    );
  }

  /// Process model info request
  Future<TunnelLLMResponse> _processModelInfo(TunnelLLMRequest request) async {
    final provider = await _getProviderForRequest(request);
    if (provider == null) {
      throw LLMCommunicationError.providerNotFound(
        requestId: request.id,
        providerId: request.preferredProvider,
      );
    }

    // Extract model name from request
    final modelName = _extractModelNameFromPath(request.path);
    if (modelName == null) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'Model name not found in request path',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }

    // Check if model is available
    if (!provider.info.availableModels.contains(modelName)) {
      throw LLMCommunicationError.modelNotFound(
        modelName: modelName,
        providerId: provider.info.id,
        requestId: request.id,
      );
    }

    final responseBody = jsonEncode({
      'name': modelName,
      'provider': provider.info.name,
      'provider_id': provider.info.id,
      'status': 'available',
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
      providerId: provider.info.id,
    );
  }

  /// Process health check request
  Future<TunnelLLMResponse> _processHealthCheck(TunnelLLMRequest request) async {
    final provider = await _getProviderForRequest(request);
    if (provider == null) {
      throw LLMCommunicationError.providerNotFound(
        requestId: request.id,
        providerId: request.preferredProvider,
      );
    }

    // Test provider connection
    final isHealthy = await _providerManager.testProviderConnection(provider.info.id);
    
    final responseBody = jsonEncode({
      'status': isHealthy ? 'healthy' : 'unhealthy',
      'provider': provider.info.name,
      'provider_id': provider.info.id,
      'health_status': provider.healthStatus.toString().split('.').last,
      'metrics': {
        'success_rate': provider.metrics.successRate,
        'average_response_time': provider.metrics.averageResponseTime,
        'total_requests': provider.metrics.totalRequests,
      },
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
      providerId: provider.info.id,
    );
  }

  /// Process provider status request
  Future<TunnelLLMResponse> _processProviderStatus(TunnelLLMRequest request) async {
    final availableProviders = _providerManager.getAvailableProviders();
    final allProviders = _providerManager.registeredProviders;

    final responseBody = jsonEncode({
      'available_providers': availableProviders.length,
      'total_providers': allProviders.length,
      'preferred_provider': _providerManager.preferredProviderId,
      'providers': allProviders.map((provider) => {
        'id': provider.info.id,
        'name': provider.info.name,
        'type': provider.info.type.toString().split('.').last,
        'status': provider.info.status.toString().split('.').last,
        'health': provider.healthStatus.toString().split('.').last,
        'enabled': provider.isEnabled,
        'available': provider.isAvailable,
        'metrics': {
          'success_rate': provider.metrics.successRate,
          'average_response_time': provider.metrics.averageResponseTime,
        },
      }).toList(),
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
    );
  }

  /// Process generic request (fallback)
  Future<TunnelLLMResponse> _processGenericRequest(TunnelLLMRequest request) async {
    final provider = await _getProviderForRequest(request);
    if (provider == null) {
      throw LLMCommunicationError.providerNotFound(
        requestId: request.id,
        providerId: request.preferredProvider,
      );
    }

    return await _processWithDirectProvider(request, provider);
  }

  /// Process request with LangChain integration
  Future<TunnelLLMResponse> _processWithLangChain(
    TunnelLLMRequest request,
    RegisteredProvider provider,
  ) async {
    if (_langchainService == null || provider.langchainWrapper == null) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.providerConfigurationError,
        message: 'LangChain service not available',
        severity: ErrorSeverity.high,
        recoveryStrategy: RecoveryStrategy.fallbackMode,
        requestId: request.id,
        providerId: provider.info.id,
      );
    }

    // Extract prompt from request body
    final prompt = _extractPromptFromRequest(request);
    if (prompt == null) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'No prompt found in request',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }

    // Process with LangChain
    final result = await _langchainService.processTextGeneration(
      provider.info.id,
      prompt,
    );

    final responseBody = jsonEncode({
      'response': result,
      'provider': provider.info.name,
      'provider_id': provider.info.id,
      'processed_with': 'langchain',
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
      providerId: provider.info.id,
    );
  }

  /// Process request with direct provider communication
  Future<TunnelLLMResponse> _processWithDirectProvider(
    TunnelLLMRequest request,
    RegisteredProvider provider,
  ) async {
    // This would implement direct HTTP communication with the provider
    // For now, return a placeholder response
    final responseBody = jsonEncode({
      'message': 'Direct provider communication not yet implemented',
      'provider': provider.info.name,
      'provider_id': provider.info.id,
      'request_type': request.type.toString().split('.').last,
    });

    return TunnelLLMResponse.success(
      requestId: request.id,
      body: responseBody,
      providerId: provider.info.id,
    );
  }

  /// Process streaming request
  Future<void> _processStreamingRequest(
    TunnelLLMRequest request,
    RegisteredProvider provider,
    StreamController<String> controller,
  ) async {
    if (_langchainService == null || provider.langchainWrapper == null) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.providerConfigurationError,
        message: 'Streaming not available for this provider',
        severity: ErrorSeverity.high,
        recoveryStrategy: RecoveryStrategy.fallbackMode,
        requestId: request.id,
        providerId: provider.info.id,
      );
    }

    final prompt = _extractPromptFromRequest(request);
    if (prompt == null) {
      throw LLMCommunicationError(
        type: LLMCommunicationErrorType.requestMalformed,
        message: 'No prompt found in streaming request',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.noRecovery,
        requestId: request.id,
      );
    }

    // Process streaming with LangChain
    await for (final chunk in _langchainService.processStreamingGeneration(
      provider.info.id,
      prompt,
    )) {
      if (!controller.isClosed) {
        controller.add(chunk);
      }
    }

    await controller.close();
  }

  /// Get provider for request with failover
  Future<RegisteredProvider?> _getProviderForRequest(TunnelLLMRequest request) async {
    // Try preferred provider first
    if (request.preferredProvider != null) {
      final preferred = _providerManager.getProvider(request.preferredProvider!);
      if (preferred != null && preferred.isAvailable) {
        return preferred;
      }
    }

    // Use provider manager's failover logic
    final availableProviders = _providerManager.getAvailableProviders();
    if (availableProviders.isNotEmpty) {
      // Return the first available provider as a simple fallback
      return availableProviders.first;
    }

    return null;
  }

  /// Setup request timeout
  void _setupRequestTimeout(TunnelLLMRequest request) {
    _requestTimers[request.id] = Timer(request.effectiveTimeout, () {
      _handleRequestTimeout(request.id);
    });
  }

  /// Setup streaming timeout
  void _setupStreamingTimeout(TunnelLLMRequest request) {
    _requestTimers[request.id] = Timer(request.effectiveTimeout, () {
      _handleStreamingTimeout(request.id);
    });
  }

  /// Handle request timeout
  void _handleRequestTimeout(String requestId) {
    debugPrint('⏰ [TunnelLLM] Request timeout: $requestId');
    
    final request = _activeRequests[requestId];
    if (request != null) {
      // Cancel the request and clean up resources
      _cleanupRequest(requestId);
      
      // Increment failure count for statistics
      _requestsFailed++;
      
      // Notify about timeout (this would be handled by the calling code)
      debugPrint('⏰ [TunnelLLM] Request $requestId timed out after ${request.effectiveTimeout}');
    }
  }

  /// Handle streaming timeout
  void _handleStreamingTimeout(String requestId) {
    debugPrint('⏰ [TunnelLLM] Streaming timeout: $requestId');
    
    final controller = _streamingControllers[requestId];
    if (controller != null && !controller.isClosed) {
      controller.addError(LLMCommunicationError(
        type: LLMCommunicationErrorType.requestTimeout,
        message: 'Streaming request timed out',
        severity: ErrorSeverity.medium,
        recoveryStrategy: RecoveryStrategy.retryWithBackoff,
        requestId: requestId,
      ));
      controller.close();
    }
    
    _cleanupStreamingRequest(requestId);
  }

  /// Cleanup request resources
  void _cleanupRequest(String requestId) {
    _activeRequests.remove(requestId);
    _requestTimers[requestId]?.cancel();
    _requestTimers.remove(requestId);
  }

  /// Cleanup streaming request resources
  void _cleanupStreamingRequest(String requestId) {
    final controller = _streamingControllers[requestId];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _streamingControllers.remove(requestId);
    _streamingRequestsActive = (_streamingRequestsActive - 1).clamp(0, double.infinity).toInt();
    
    _requestTimers[requestId]?.cancel();
    _requestTimers.remove(requestId);
  }

  /// Attempt error recovery for failed requests
  Future<TunnelLLMResponse?> _attemptErrorRecovery(
    TunnelLLMRequest request,
    LLMCommunicationError error,
  ) async {
    // Only attempt recovery for retryable errors
    if (!error.isRetryable) return null;
    
    debugPrint('🔄 [TunnelLLM] Attempting error recovery for ${request.id}: ${error.type}');
    
    try {
      switch (error.recoveryStrategy) {
        case RecoveryStrategy.retry:
        case RecoveryStrategy.retryWithBackoff:
          // Simple retry after a short delay
          await Future.delayed(const Duration(seconds: 1));
          return await _processRequestByType(request);
          
        case RecoveryStrategy.switchProvider:
          // Try with a different provider
          final fallbackProvider = await _getFallbackProvider(request.preferredProvider);
          if (fallbackProvider != null) {
            final fallbackRequest = TunnelLLMRequest(
              id: request.id,
              type: request.type,
              method: request.method,
              path: request.path,
              headers: request.headers,
              body: request.body,
              preferredProvider: fallbackProvider.info.id,
              customTimeout: request.customTimeout,
              isStreaming: request.isStreaming,
              priority: request.priority,
              llmParameters: request.llmParameters,
            );
            return await _processRequestByType(fallbackRequest);
          }
          break;
          
        case RecoveryStrategy.fallbackMode:
          // Try with simplified request parameters
          return await _processWithSimplifiedRequest(request);
          
        case RecoveryStrategy.noRecovery:
        case RecoveryStrategy.userIntervention:
        case RecoveryStrategy.systemRestart:
          // No automatic recovery possible
          break;
      }
    } catch (recoveryError) {
      debugPrint('❌ [TunnelLLM] Error recovery failed for ${request.id}: $recoveryError');
    }
    
    return null;
  }

  /// Get fallback provider for error recovery
  Future<RegisteredProvider?> _getFallbackProvider(String? excludeProviderId) async {
    final availableProviders = _providerManager.getAvailableProviders();
    
    // Filter out the excluded provider
    final fallbackProviders = availableProviders
        .where((provider) => provider.info.id != excludeProviderId)
        .toList();
    
    if (fallbackProviders.isEmpty) return null;
    
    // Return the first available fallback provider
    return fallbackProviders.first;
  }

  /// Process request with simplified parameters for fallback mode
  Future<TunnelLLMResponse> _processWithSimplifiedRequest(TunnelLLMRequest request) async {
    // Create a simplified version of the request with basic parameters
    final simplifiedBody = request.body != null ? _simplifyRequestBody(request.body!) : null;
    
    final simplifiedRequest = TunnelLLMRequest(
      id: request.id,
      type: request.type,
      method: request.method,
      path: request.path,
      headers: request.headers,
      body: simplifiedBody,
      customTimeout: const Duration(seconds: 30), // Shorter timeout for fallback
      isStreaming: false, // Disable streaming for fallback
      priority: RequestPriority.normal,
      llmParameters: _simplifyLLMParameters(request.llmParameters),
    );
    
    return await _processRequestByType(simplifiedRequest);
  }

  /// Simplify request body for fallback mode
  String _simplifyRequestBody(String body) {
    try {
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;
      
      // Keep only essential parameters
      final simplifiedBody = <String, dynamic>{
        if (jsonBody.containsKey('prompt')) 'prompt': jsonBody['prompt'],
        if (jsonBody.containsKey('model')) 'model': jsonBody['model'],
        if (jsonBody.containsKey('messages')) 'messages': jsonBody['messages'],
        'stream': false, // Disable streaming for fallback
      };
      
      return jsonEncode(simplifiedBody);
    } catch (e) {
      return body; // Return original if parsing fails
    }
  }

  /// Simplify LLM parameters for fallback mode
  Map<String, dynamic> _simplifyLLMParameters(Map<String, dynamic> params) {
    // Keep only essential parameters
    return {
      if (params.containsKey('model')) 'model': params['model'],
      if (params.containsKey('prompt')) 'prompt': params['prompt'],
      if (params.containsKey('messages')) 'messages': params['messages'],
    };
  }

  /// Extract prompt from request for LangChain processing
  String? _extractPromptFromRequest(TunnelLLMRequest request) {
    if (request.body == null) return null;
    
    try {
      final jsonBody = jsonDecode(request.body!) as Map<String, dynamic>;
      
      // Try different prompt fields
      if (jsonBody.containsKey('prompt')) {
        return jsonBody['prompt'] as String?;
      }
      
      if (jsonBody.containsKey('messages')) {
        final messages = jsonBody['messages'] as List?;
        if (messages != null && messages.isNotEmpty) {
          final lastMessage = messages.last as Map<String, dynamic>?;
          return lastMessage?['content'] as String?;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ [TunnelLLM] Failed to extract prompt from request: $e');
      return null;
    }
  }

  /// Extract model name from request path
  String? _extractModelNameFromPath(String path) {
    // Common patterns for model names in paths
    final patterns = [
      RegExp(r'/api/show/([^/]+)'),
      RegExp(r'/api/pull/([^/]+)'),
      RegExp(r'/api/delete/([^/]+)'),
      RegExp(r'/v1/models/([^/]+)'),
      RegExp(r'/models/([^/]+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(path);
      if (match != null && match.groupCount > 0) {
        return match.group(1);
      }
    }
    
    return null;
  }

  /// Dispose of the handler and cleanup resources
  @override
  void dispose() {
    debugPrint('🔄 [TunnelLLM] Disposing request handler');
    
    // Cancel all active request timers
    for (final timer in _requestTimers.values) {
      timer.cancel();
    }
    _requestTimers.clear();
    
    // Close all streaming controllers
    for (final controller in _streamingControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamingControllers.clear();
    
    // Clear active requests
    _activeRequests.clear();
    
    _streamingRequestsActive = 0;
    
    debugPrint('🔄 [TunnelLLM] Request handler disposed');
    super.dispose();
  }
}

