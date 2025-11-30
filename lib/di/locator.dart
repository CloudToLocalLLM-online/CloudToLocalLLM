import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../services/admin_data_flush_service.dart';
import '../services/admin_service.dart';
import '../services/app_initialization_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';
import '../services/connection_manager_service.dart';
import '../services/desktop_client_detection_service.dart';
import '../services/enhanced_user_tier_service.dart';
import '../services/langchain_integration_service.dart';
import '../services/langchain_ollama_service.dart';
import '../services/langchain_prompt_service.dart';
import '../services/langchain_rag_service.dart'
    if (dart.library.html) '../services/langchain_rag_service_stub.dart';
import '../services/llm_audit_service.dart';
import '../services/llm_error_handler.dart';
import '../services/llm_provider_manager.dart';
import '../services/local_ollama_connection_service.dart';
import '../services/ollama_service.dart';
import '../services/provider_discovery_service.dart';
import '../services/streaming_chat_service.dart';
import '../services/streaming_proxy_service.dart';
import '../services/tunnel_service.dart';
import '../services/tunnel/tunnel_config_manager.dart';
import '../services/unified_connection_service.dart';
import '../services/user_container_service.dart';
import '../services/web_download_prompt_service.dart'
    if (dart.library.io) '../services/web_download_prompt_service_stub.dart';
import '../services/settings_preference_service.dart';
import '../services/settings_import_export_service.dart';
import '../services/provider_configuration_manager.dart';
import '../services/admin_center_service.dart';
import '../services/theme_provider.dart';
import '../services/platform_detection_service.dart';
import '../services/platform_adapter.dart';

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

  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES START =====');
  debugPrint('[ServiceLocator] Registering core services...');

  // Session storage service for PostgreSQL session management
  final sessionStorageService = SessionStorageService();
  serviceLocator
      .registerSingleton<SessionStorageService>(sessionStorageService);

  // Supabase Auth service
  final supabaseAuthService = SupabaseAuthService();
  serviceLocator.registerSingleton<SupabaseAuthService>(supabaseAuthService);

  final authService = AuthService(supabaseAuthService);
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

  // LangChain Prompt Service - create but don't initialize templates until auth
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

  // Settings preference service - manages user preferences
  final settingsPreferenceService = SettingsPreferenceService();
  serviceLocator.registerSingleton<SettingsPreferenceService>(
    settingsPreferenceService,
  );

  // Settings import/export service - handles settings backup/restore
  final settingsImportExportService = SettingsImportExportService(
    preferencesService: settingsPreferenceService,
  );
  serviceLocator.registerSingleton<SettingsImportExportService>(
    settingsImportExportService,
  );

  // Platform detection service - detects current platform and provides platform info
  final platformDetectionService = PlatformDetectionService();
  serviceLocator.registerSingleton<PlatformDetectionService>(
    platformDetectionService,
  );

  // Platform adapter - provides platform-appropriate UI components
  final platformAdapter = PlatformAdapter(platformDetectionService);
  serviceLocator.registerSingleton<PlatformAdapter>(platformAdapter);

  // Theme provider - manages application theme mode
  final themeProvider = ThemeProvider();
  serviceLocator.registerSingleton<ThemeProvider>(themeProvider);

  // Provider configuration manager - manages local LLM provider configurations
  final providerConfigurationManager = ProviderConfigurationManager();
  serviceLocator.registerSingleton<ProviderConfigurationManager>(
    providerConfigurationManager,
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
  debugPrint('[ServiceLocator] ===== REGISTERING CORE SERVICES END =====');

  // Verify all core services are registered
  _verifyCoreServicesRegistered();
}

/// Verify that all critical core services are registered
void _verifyCoreServicesRegistered() {
  final criticalServices = [
    'AuthService',
    'ThemeProvider',
    'ProviderConfigurationManager',
    'LocalOllamaConnectionService',
    'DesktopClientDetectionService',
    'AppInitializationService',
  ];

  debugPrint('[ServiceLocator] Verifying core services registration...');
  for (final serviceName in criticalServices) {
    try {
      switch (serviceName) {
        case 'AuthService':
          if (serviceLocator.isRegistered<AuthService>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
        case 'ThemeProvider':
          if (serviceLocator.isRegistered<ThemeProvider>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
        case 'ProviderConfigurationManager':
          if (serviceLocator.isRegistered<ProviderConfigurationManager>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
        case 'LocalOllamaConnectionService':
          if (serviceLocator.isRegistered<LocalOllamaConnectionService>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
        case 'DesktopClientDetectionService':
          if (serviceLocator.isRegistered<DesktopClientDetectionService>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
        case 'AppInitializationService':
          if (serviceLocator.isRegistered<AppInitializationService>()) {
            debugPrint('[ServiceLocator] ✓ $serviceName registered');
          } else {
            debugPrint('[ServiceLocator] ✗ $serviceName NOT registered');
          }
          break;
      }
    } catch (e) {
      debugPrint('[ServiceLocator] Error checking $serviceName: $e');
    }
  }
}

/// Registers authenticated services that require authentication tokens.
/// These services should only be registered after the user has authenticated.
/// This prevents unnecessary initialization and improves security.
Future<void> setupAuthenticatedServices() async {
  if (_authenticatedServicesRegistered) {
    debugPrint('[ServiceLocator] Authenticated services already registered');
    // Services are already registered, so we're done
    return;
  }

  debugPrint(
      '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES START =====');

  // Verify authentication before proceeding
  final authService = serviceLocator.get<AuthService>();
  if (!authService.isAuthenticated.value) {
    debugPrint(
      '[ServiceLocator] Cannot register authenticated services - user not authenticated',
    );
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES END (SKIPPED) =====');
    return;
  }

  // Verify token is available
  final token = await authService.getAccessToken();
  if (token == null || token.isEmpty) {
    debugPrint(
      '[ServiceLocator] Cannot register authenticated services - no access token',
    );
    debugPrint(
        '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES END (SKIPPED) =====');
    return;
  }

  debugPrint('[ServiceLocator] Registering authenticated services...');
  _authenticatedServicesRegistered = true;

  final localOllamaService = serviceLocator.get<LocalOllamaConnectionService>();
  final providerDiscoveryService =
      serviceLocator.get<ProviderDiscoveryService>();
  final enhancedUserTierService = serviceLocator.get<EnhancedUserTierService>();
  final webDownloadPromptService =
      serviceLocator.get<WebDownloadPromptService>();

  // Initialize enhanced user tier service now that we have auth
  unawaited(enhancedUserTierService.initialize());

  // Initialize web download prompt service
  await webDownloadPromptService.initialize();

  // Initialize LocalOllama service now that we have auth
  await localOllamaService.initialize();

  // LangChain Prompt Service is already initialized in constructor

  // Provider Discovery Service doesn't need initialization - it's already set up

  // Tunnel configuration manager - requires SharedPreferences
  final tunnelConfigManager = TunnelConfigManager();
  await tunnelConfigManager.initialize();
  serviceLocator.registerSingleton<TunnelConfigManager>(tunnelConfigManager);

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

  // Admin center service - requires authentication
  final adminCenterService = AdminCenterService(authService: authService);
  serviceLocator.registerSingleton<AdminCenterService>(adminCenterService);

  debugPrint('[ServiceLocator] Authenticated services registered successfully');
  debugPrint(
      '[ServiceLocator] ===== REGISTERING AUTHENTICATED SERVICES END =====');
}

/// Legacy function for backward compatibility.
/// Now delegates to setupCoreServices() to maintain existing code.
Future<void> setupServiceLocator() async {
  await setupCoreServices();
}
