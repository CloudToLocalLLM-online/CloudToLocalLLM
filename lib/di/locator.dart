import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../services/admin_data_flush_service.dart';
import '../services/admin_service.dart';
import '../services/app_initialization_service.dart';
import '../services/auth0_desktop_service.dart';
import '../services/auth0_service.dart';
import '../services/auth0_web_service.dart'
    if (dart.library.io) '../services/auth0_web_service_stub.dart';
import '../services/auth_service.dart';
import '../services/connection_manager_service.dart';
import '../services/desktop_client_detection_service.dart';
import '../services/enhanced_user_tier_service.dart';
import '../services/langchain_integration_service.dart';
import '../services/langchain_ollama_service.dart';
import '../services/langchain_prompt_service.dart';
import '../services/langchain_rag_service.dart';
import '../services/llm_audit_service.dart';
import '../services/llm_error_handler.dart';
import '../services/llm_provider_manager.dart';
import '../services/local_ollama_connection_service.dart';
import '../services/ollama_service.dart';
import '../services/provider_discovery_service.dart';
import '../services/streaming_chat_service.dart';
import '../services/streaming_proxy_service.dart';
import '../services/tunnel_service.dart';
import '../services/unified_connection_service.dart';
import '../services/user_container_service.dart';
import '../services/web_download_prompt_service.dart'
    if (dart.library.io) '../services/web_download_prompt_service_stub.dart';

final GetIt serviceLocator = GetIt.instance;

bool _coreServicesRegistered = false;
bool _authenticatedServicesRegistered = false;

/// Registers core services that are needed before authentication.
/// These services don't require authentication tokens and can be safely
/// initialized during app bootstrap.
Future<void> setupCoreServices() async {
  if (_coreServicesRegistered) {
    return;
  }
  _coreServicesRegistered = true;

  debugPrint('[ServiceLocator] Registering core services...');

  // Auth0 and Auth services - needed for authentication flow
  final auth0Service = kIsWeb ? Auth0WebService() : Auth0DesktopService();
  serviceLocator.registerSingleton<Auth0Service>(auth0Service);

  final authService = AuthService(auth0Service);
  await authService.init();
  serviceLocator.registerSingleton<AuthService>(authService);

  // Local Ollama service - create but don't initialize until auth
  final localOllamaService = LocalOllamaConnectionService();
  serviceLocator.registerSingleton<LocalOllamaConnectionService>(
    localOllamaService,
  );

  // Provider discovery - create but don't initialize until auth
  final providerDiscoveryService = ProviderDiscoveryService();
  serviceLocator.registerSingleton<ProviderDiscoveryService>(
    providerDiscoveryService,
  );

  // LLM Error Handler - lightweight, doesn't require auth
  final llmErrorHandler = LLMErrorHandler(
    providerDiscovery: providerDiscoveryService,
  );
  serviceLocator.registerSingleton<LLMErrorHandler>(llmErrorHandler);

  // LangChain Prompt Service - lightweight, doesn't require auth
  final langchainPromptService = LangChainPromptService();
  serviceLocator.registerSingleton<LangChainPromptService>(
    langchainPromptService,
  );

  // Desktop client detection - can check client type without auth
  final desktopClientDetectionService = DesktopClientDetectionService(
    authService: authService,
  );
  serviceLocator.registerSingleton<DesktopClientDetectionService>(
    desktopClientDetectionService,
  );

  // App initialization service - manages initialization order
  final appInitializationService = AppInitializationService(
    authService: authService,
  );
  serviceLocator.registerSingleton<AppInitializationService>(
    appInitializationService,
  );

  // Web download prompt service - can be created but won't do heavy work until auth
  final webDownloadPromptService = WebDownloadPromptService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
  // Don't initialize yet - wait for auth
  serviceLocator.registerSingleton<WebDownloadPromptService>(
    webDownloadPromptService,
  );

  // Enhanced user tier service - can be created but won't initialize until auth
  final enhancedUserTierService = EnhancedUserTierService(
    authService: authService,
  );
  serviceLocator.registerSingleton<EnhancedUserTierService>(
    enhancedUserTierService,
  );
  // Don't initialize yet - wait for auth token

  debugPrint('[ServiceLocator] Core services registered successfully');
}

/// Registers authenticated services that require authentication tokens.
/// These services should only be registered after the user has authenticated.
/// This prevents unnecessary initialization and improves security.
Future<void> setupAuthenticatedServices() async {
  if (_authenticatedServicesRegistered) {
    debugPrint('[ServiceLocator] Authenticated services already registered');
    return;
  }

  // Verify authentication before proceeding
  final authService = serviceLocator.get<AuthService>();
  if (!authService.isAuthenticated.value) {
    debugPrint(
      '[ServiceLocator] Cannot register authenticated services - user not authenticated',
    );
    return;
  }

  // Verify token is available
  final token = await authService.getAccessToken();
  if (token == null || token.isEmpty) {
    debugPrint(
      '[ServiceLocator] Cannot register authenticated services - no access token',
    );
    return;
  }

  debugPrint('[ServiceLocator] Registering authenticated services...');
  _authenticatedServicesRegistered = true;

  final localOllamaService = serviceLocator.get<LocalOllamaConnectionService>();
  final providerDiscoveryService =
      serviceLocator.get<ProviderDiscoveryService>();
  final enhancedUserTierService =
      serviceLocator.get<EnhancedUserTierService>();
  final webDownloadPromptService =
      serviceLocator.get<WebDownloadPromptService>();

  // Initialize enhanced user tier service now that we have auth
  unawaited(enhancedUserTierService.initialize());

  // Initialize web download prompt service
  await webDownloadPromptService.initialize();

  // Initialize LocalOllama service now that we have auth
  await localOllamaService.initialize();

  // Tunnel service - requires authentication token
  final tunnelService = TunnelService(authService: authService);
  serviceLocator.registerSingleton<TunnelService>(tunnelService);

  // Streaming proxy service - requires authentication token
  final streamingProxyService = StreamingProxyService(authService: authService);
  serviceLocator.registerSingleton<StreamingProxyService>(
    streamingProxyService,
  );

  // Ollama service - requires authentication token
  final ollamaService = OllamaService(authService: authService);
  await ollamaService.initialize();
  serviceLocator.registerSingleton<OllamaService>(ollamaService);

  // User container service - requires authentication token
  final userContainerService = UserContainerService(authService: authService);
  serviceLocator.registerSingleton<UserContainerService>(userContainerService);

  // LangChain integration service - requires authentication for provider access
  final langchainIntegrationService = LangChainIntegrationService(
    discoveryService: providerDiscoveryService,
  );
  await langchainIntegrationService.initializeProviders();
  serviceLocator.registerSingleton<LangChainIntegrationService>(
    langchainIntegrationService,
  );

  // LLM Provider Manager - requires authentication
  final llmProviderManager = LLMProviderManager(
    discoveryService: providerDiscoveryService,
    langchainService: langchainIntegrationService,
  );
  await llmProviderManager.initialize();
  serviceLocator.registerSingleton<LLMProviderManager>(llmProviderManager);

  // Connection Manager - requires authentication for tunnel/cloud connections
  final connectionManager = ConnectionManagerService(
    localOllama: localOllamaService,
    tunnelService: tunnelService,
    authService: authService,
    ollamaService: ollamaService,
  );
  await connectionManager.initialize();
  serviceLocator.registerSingleton<ConnectionManagerService>(connectionManager);

  // LangChain Ollama service - requires connection manager (which requires auth)
  final langchainOllamaService = LangChainOllamaService(
    connectionManager: connectionManager,
  );
  await langchainOllamaService.initialize();
  serviceLocator.registerSingleton<LangChainOllamaService>(
    langchainOllamaService,
  );

  // LangChain RAG service - requires LangChain Ollama service
  final langchainRagService = LangChainRAGService(
    ollamaService: langchainOllamaService,
  );
  await langchainRagService.initialize();
  serviceLocator.registerSingleton<LangChainRAGService>(langchainRagService);

  // LLM Audit service - requires authentication
  final llmAuditService = LLMAuditService(authService: authService);
  await llmAuditService.initialize();
  serviceLocator.registerSingleton<LLMAuditService>(llmAuditService);

  // Streaming chat service - requires connection manager
  final streamingChatService = StreamingChatService(
    connectionManager,
    authService,
  );
  serviceLocator.registerSingleton<StreamingChatService>(streamingChatService);

  // Unified connection service - requires connection manager
  final unifiedConnectionService = UnifiedConnectionService();
  unifiedConnectionService.setConnectionManager(connectionManager);
  await unifiedConnectionService.initialize();
  serviceLocator.registerSingleton<UnifiedConnectionService>(
    unifiedConnectionService,
  );

  // Admin services - require authentication and admin privileges
  final adminService = AdminService(authService: authService);
  serviceLocator.registerSingleton<AdminService>(adminService);

  final adminDataFlushService = AdminDataFlushService(authService: authService);
  serviceLocator.registerSingleton<AdminDataFlushService>(
    adminDataFlushService,
  );

  debugPrint('[ServiceLocator] Authenticated services registered successfully');
}

/// Legacy function for backward compatibility.
/// Now delegates to setupCoreServices() to maintain existing code.
Future<void> setupServiceLocator() async {
  await setupCoreServices();
}
