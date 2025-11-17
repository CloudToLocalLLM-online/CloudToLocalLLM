import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'bootstrap/bootstrapper.dart';
import 'config/app_config.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'screens/loading_screen.dart';
import 'di/locator.dart' as di;
import 'services/admin_center_service.dart';
import 'services/admin_data_flush_service.dart';
import 'services/admin_service.dart';
import 'services/app_initialization_service.dart';
import 'services/auth_service.dart';
import 'services/connection_manager_service.dart';
import 'services/desktop_client_detection_service.dart';
import 'services/enhanced_user_tier_service.dart';
import 'services/langchain_integration_service.dart';
import 'services/langchain_ollama_service.dart';
import 'services/langchain_prompt_service.dart';
import 'services/langchain_rag_service.dart';
import 'services/llm_audit_service.dart';
import 'services/llm_error_handler.dart';
import 'services/llm_provider_manager.dart';
import 'services/local_ollama_connection_service.dart';
import 'services/ollama_service.dart';
import 'services/provider_configuration_manager.dart';
import 'services/provider_discovery_service.dart';
import 'services/streaming_chat_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/tunnel_service.dart';
import 'services/unified_connection_service.dart';
import 'services/user_container_service.dart';
import 'services/web_download_prompt_service.dart'
    if (dart.library.io) 'services/web_download_prompt_service_stub.dart';
import 'services/log_buffer_service.dart';
import 'services/theme_provider.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'widgets/tray_initializer.dart';
import 'widgets/window_listener_widget.dart'
    if (dart.library.html) 'widgets/window_listener_widget_stub.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initializeClientLogBuffer();

  Future<AppBootstrapData> loadApp() async {
    // Note: Auth0 callback handling is now done by the router and CallbackScreen
    // The router will detect callback parameters and route to /callback,
    // where CallbackScreen will process the authentication

    // Run the main bootstrap process
    final bootstrapper = AppBootstrapper();
    return await bootstrapper.load();
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: \'${details.exception}\'');
    if (details.stack != null) {
      debugPrint('Stack trace: ${details.stack}');
    }
  };

  runZonedGuarded(
    () {
      runApp(
        FutureProvider<AppBootstrapData?>(
          create: (_) => appLoadFuture,
          initialData: null,
          child: const CloudToLocalLLMApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}

void _initializeClientLogBuffer() {
  if (!kIsWeb) {
    return;
  }

  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogBufferService.instance.add(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
}

/// Main application widget with comprehensive loading screen
class CloudToLocalLLMApp extends StatefulWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  bool _authListenerAttached = false;
  AuthService? _attachedAuthService;

  @override
  void dispose() {
    if (_authListenerAttached && _attachedAuthService != null) {
      _attachedAuthService!.removeListener(_onAuthStateChanged);
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Rebuild when auth state changes so authenticated services can be provided
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<AppBootstrapData?>();
    if (bootstrap == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(message: 'Initializing CloudToLocalLLM...'),
      );
    }

    _ensureAuthListener();

    // Build providers list - authenticated services will be added when registered
    // This rebuilds when auth state changes
    return MultiProvider(
      providers: _buildProviders(),
      child: TrayInitializer(
        navigatorKey: navigatorKey,
        child: const _AppRouterHost(),
      ),
    );
  }

  void _ensureAuthListener() {
    if (_authListenerAttached) {
      return;
    }
    if (!di.serviceLocator.isRegistered<AuthService>()) {
      debugPrint(
          '[App] AuthService not registered yet - deferring listener attachment');
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;
  }

  List<SingleChildWidget> _buildProviders() {
    final providers = <SingleChildWidget>[];

    // Core services - always available
    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<AuthService>(),
      ),
    );

    // Core services that don't require authentication
    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LocalOllamaConnectionService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<DesktopClientDetectionService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<AppInitializationService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<WebDownloadPromptService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<ProviderDiscoveryService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LLMErrorHandler>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LangChainPromptService>(),
      ),
    );

    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<EnhancedUserTierService>(),
      ),
    );

    // Theme provider - manages application theme
    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<ThemeProvider>(),
      ),
    );

    // ProviderConfigurationManager is always registered, add unconditionally
    providers.add(
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<ProviderConfigurationManager>(),
      ),
    );

    // Authenticated services - only provide if registered
    // These will be registered after authentication
    _addProviderIfRegistered<TunnelService>(providers);
    _addProviderIfRegistered<StreamingProxyService>(providers);
    _addProviderIfRegistered<OllamaService>(providers);
    _addProviderIfRegistered<UserContainerService>(providers);
    _addProviderIfRegistered<LangChainIntegrationService>(providers);
    _addProviderIfRegistered<LLMProviderManager>(providers);
    _addProviderIfRegistered<ConnectionManagerService>(providers);
    _addProviderIfRegistered<LangChainOllamaService>(providers);
    _addProviderIfRegistered<LangChainRAGService>(providers);
    _addProviderIfRegistered<LLMAuditService>(providers);
    _addProviderIfRegistered<StreamingChatService>(providers);
    _addProviderIfRegistered<UnifiedConnectionService>(providers);
    _addProviderIfRegistered<AdminService>(providers);
    _addProviderIfRegistered<AdminDataFlushService>(providers);
    _addProviderIfRegistered<AdminCenterService>(providers);

    return providers;
  }

  /// Helper method to safely add a provider only if the service is registered
  void _addProviderIfRegistered<T extends ChangeNotifier>(
    List<SingleChildWidget> providers,
  ) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        providers.add(
          ChangeNotifierProvider.value(
            value: di.serviceLocator.get<T>(),
          ),
        );
      }
    } catch (e) {
      // Service not registered yet - skip it
      debugPrint('[Providers] Service $T not registered yet, skipping');
    }
  }
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  GoRouter? _router;
  bool _waitingForBootstrap = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null || _waitingForBootstrap) {
      return;
    }

    final authService = context.read<AuthService>();
    if (authService.isSessionBootstrapComplete) {
      _initializeRouter(authService);
    } else {
      _waitingForBootstrap = true;
      authService.sessionBootstrapFuture.whenComplete(() {
        if (!mounted) {
          return;
        }
        _waitingForBootstrap = false;
        _initializeRouter(authService);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(message: 'Preparing router...'),
      );
    }

    // Get theme provider from context
    final themeProvider = context.watch<ThemeProvider>();

    return WindowListenerWidget(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        routerConfig: router,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  void _initializeRouter(AuthService authService) {
    setState(() {
      _router = AppRouter.createRouter(
        navigatorKey: navigatorKey,
        authService: authService,
      );
    });
  }
}
