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

/// Registers application-wide singletons and factories. This is invoked during
/// bootstrap and ensures heavy dependency construction happens once.
Future<void> setupServiceLocator() async {
  if (_coreServicesRegistered) {
    return;
  }
  _coreServicesRegistered = true;

  final auth0Service = kIsWeb ? Auth0WebService() : Auth0DesktopService();
  serviceLocator.registerSingleton<Auth0Service>(auth0Service);

  final authService = AuthService(auth0Service);
  await authService.init();
  serviceLocator.registerSingleton<AuthService>(authService);

  final enhancedUserTierService = EnhancedUserTierService(
    authService: authService,
  );
  await enhancedUserTierService.initialize();
  serviceLocator.registerSingleton<EnhancedUserTierService>(
    enhancedUserTierService,
  );

  final tunnelService = TunnelService(authService: authService);
  serviceLocator.registerSingleton<TunnelService>(tunnelService);

  final streamingProxyService = StreamingProxyService(authService: authService);
  serviceLocator.registerSingleton<StreamingProxyService>(
    streamingProxyService,
  );

  final ollamaService = OllamaService(authService: authService);
  await ollamaService.initialize();
  serviceLocator.registerSingleton<OllamaService>(ollamaService);

  final localOllamaService = LocalOllamaConnectionService();
  await localOllamaService.initialize();
  serviceLocator.registerSingleton<LocalOllamaConnectionService>(
    localOllamaService,
  );

  final desktopClientDetectionService = DesktopClientDetectionService(
    authService: authService,
  );
  serviceLocator.registerSingleton<DesktopClientDetectionService>(
    desktopClientDetectionService,
  );

  final appInitializationService = AppInitializationService(
    authService: authService,
  );
  serviceLocator.registerSingleton<AppInitializationService>(
    appInitializationService,
  );

  final webDownloadPromptService = WebDownloadPromptService(
    authService: authService,
    clientDetectionService: desktopClientDetectionService,
  );
  await webDownloadPromptService.initialize();
  serviceLocator.registerSingleton<WebDownloadPromptService>(
    webDownloadPromptService,
  );

  final userContainerService = UserContainerService(authService: authService);
  serviceLocator.registerSingleton<UserContainerService>(userContainerService);

  final providerDiscoveryService = ProviderDiscoveryService();
  serviceLocator.registerSingleton<ProviderDiscoveryService>(
    providerDiscoveryService,
  );

  final langchainIntegrationService = LangChainIntegrationService(
    discoveryService: providerDiscoveryService,
  );
  await langchainIntegrationService.initializeProviders();
  serviceLocator.registerSingleton<LangChainIntegrationService>(
    langchainIntegrationService,
  );

  final llmErrorHandler = LLMErrorHandler(
    providerDiscovery: providerDiscoveryService,
  );
  serviceLocator.registerSingleton<LLMErrorHandler>(llmErrorHandler);

  final llmProviderManager = LLMProviderManager(
    discoveryService: providerDiscoveryService,
    langchainService: langchainIntegrationService,
  );
  await llmProviderManager.initialize();
  serviceLocator.registerSingleton<LLMProviderManager>(llmProviderManager);

  final connectionManager = ConnectionManagerService(
    localOllama: localOllamaService,
    tunnelService: tunnelService,
    authService: authService,
    ollamaService: ollamaService,
  );
  await connectionManager.initialize();
  serviceLocator.registerSingleton<ConnectionManagerService>(connectionManager);

  final langchainPromptService = LangChainPromptService();
  serviceLocator.registerSingleton<LangChainPromptService>(
    langchainPromptService,
  );

  final langchainOllamaService = LangChainOllamaService(
    connectionManager: connectionManager,
  );
  await langchainOllamaService.initialize();
  serviceLocator.registerSingleton<LangChainOllamaService>(
    langchainOllamaService,
  );

  final langchainRagService = LangChainRAGService(
    ollamaService: langchainOllamaService,
  );
  await langchainRagService.initialize();
  serviceLocator.registerSingleton<LangChainRAGService>(langchainRagService);

  final llmAuditService = LLMAuditService(authService: authService);
  await llmAuditService.initialize();
  serviceLocator.registerSingleton<LLMAuditService>(llmAuditService);

  final streamingChatService = StreamingChatService(
    connectionManager,
    authService,
  );
  serviceLocator.registerSingleton<StreamingChatService>(streamingChatService);

  final unifiedConnectionService = UnifiedConnectionService();
  unifiedConnectionService.setConnectionManager(connectionManager);
  await unifiedConnectionService.initialize();
  serviceLocator.registerSingleton<UnifiedConnectionService>(
    unifiedConnectionService,
  );

  final adminService = AdminService(authService: authService);
  serviceLocator.registerSingleton<AdminService>(adminService);

  final adminDataFlushService = AdminDataFlushService(authService: authService);
  serviceLocator.registerSingleton<AdminDataFlushService>(
    adminDataFlushService,
  );
}
