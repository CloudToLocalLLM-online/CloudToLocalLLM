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
import 'config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'services/platform_detection_service.dart';
import 'services/platform_adapter.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'widgets/tray_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'widgets/window_listener_widget.dart'
    if (dart.library.html) 'widgets/window_listener_widget_stub.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Immediate logging to verify Dart entry point is reached
  print('----- DART MAIN START ----- v4.12.3');

  // Flutter requires WidgetsFlutterBinding to be initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry IMMEDIATELY after Flutter binding (before all other services)
  print('[Main] Initializing Sentry (FIRST after Flutter binding)...');

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = AppConfig.sentryEnvironment;
        options.release = '${AppConfig.appName}@${AppConfig.appVersion}';
        // Lower sample rate in production to reduce costs
        options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
        // Enable debug only in development
        options.debug = !kReleaseMode;
        // Enable Sentry Logs
        options.enableLogs = true;
      },
      appRunner: () async {
        print('[Main] Sentry initialized, running app with Sentry...');

        // Initialize Supabase after Sentry is ready
        print('[Main] Initializing Supabase...');
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        print('[Main] Supabase initialized');

        _runAppWithSentry();
      },
    ).timeout(const Duration(seconds: 5));
    print('[Main] Sentry init completed');
  } catch (e) {
    print('Sentry initialization failed or timed out: $e');
    // If Sentry fails, run the app anyway without Sentry wrapping

    // Initialize Supabase even if Sentry fails
    print('[Main] Initializing Supabase...');
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      print('[Main] Supabase initialized');
    } catch (supabaseError) {
      print('Supabase initialization failed: $supabaseError');
    }

    _runAppWithoutSentry();
  }
}

void _runAppWithSentry() {
  // Now that Sentry is initialized, set up error handlers
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: \'${details.exception}\'');
    if (details.stack != null) {
      debugPrint('Stack trace: ${details.stack}');
    }
    Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  };

  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppWithoutSentry() {
  print('Running app without Sentry');
  _initializeClientLogBuffer();
  _runAppCommon();
}

void _runAppCommon() {
  Future<AppBootstrapData> loadApp() async {
    // Callback handling is now done by the router and CallbackScreen
    // The router will detect callback parameters and route to /callback,
    // where CallbackScreen will process the authentication

    // Run the main bootstrap process
    try {
      print('[Main] Bootstrapper loading...');
      final bootstrapper = AppBootstrapper();
      final result = await bootstrapper.load();
      print('[Main] Bootstrapper loaded');
      return result;
    } catch (e, stack) {
      debugPrint('Bootstrap failed: $e');
      try {
        Sentry.captureException(e, stackTrace: stack);
      } catch (_) {} // Ignore Sentry errors here
      // Return minimal bootstrap data to allow app to load error screen or retry
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    }
  }

  final appLoadFuture = loadApp();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Run the app inside a zone to catch async errors
  runZonedGuarded(
    () => runApp(
      SentryWidget(
        child: FutureProvider<AppBootstrapData?>(
          create: (_) => appLoadFuture,
          initialData: null,
          child: const CloudToLocalLLMApp(),
        ),
      ),
    ),
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stack');
      try {
        Sentry.captureException(
          error,
          stackTrace: stack,
        );
      } catch (_) {} // Ignore Sentry errors here
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
    print('[App] build() called');
    final bootstrap = context.watch<AppBootstrapData?>();
    print('[App] bootstrap: $bootstrap');
    if (bootstrap == null) {
      print('[App] Bootstrap is null, showing loading screen');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    print('[App] Bootstrap loaded, building app');
    _ensureAuthListener();

    // Build providers list - authenticated services will be added when registered
    // This rebuilds when auth state changes
    try {
      return MultiProvider(
        providers: _buildProviders(),
        child: TrayInitializer(
          navigatorKey: navigatorKey,
          child: const _AppRouterHost(),
        ),
      );
    } catch (e, stack) {
      print('[App] Error building providers: $e');
      print('[App] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
      // Return error screen instead of crashing
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Initialization Error'),
                const SizedBox(height: 8),
                Text(e.toString()),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _ensureAuthListener() {
    if (_authListenerAttached) {
      return;
    }
    if (!di.serviceLocator.isRegistered<AuthService>()) {
      print(
          '[App] AuthService not registered yet - deferring listener attachment');
      return;
    }
    final authService = di.serviceLocator.get<AuthService>();
    authService.addListener(_onAuthStateChanged);
    _attachedAuthService = authService;
    _authListenerAttached = true;

    // Listen for authenticated services to load and trigger rebuild
    authService.areAuthenticatedServicesLoaded.addListener(() {
      if (authService.areAuthenticatedServicesLoaded.value && mounted) {
        print(
            '[App] Authenticated services became loaded, triggering rebuild...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              print('[App] Provider tree rebuilt with authenticated services');
            });
          }
        });
      }
    });

    // If authenticated services are already loaded, trigger a rebuild now
    // to ensure they get added to the Provider tree
    if (authService.areAuthenticatedServicesLoaded.value) {
      print(
          '[App] Authenticated services already loaded, triggering rebuild...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            print('[App] Provider tree rebuilt with authenticated services');
          });
        }
      });
    }
  }

  List<SingleChildWidget> _buildProviders() {
    final providers = <SingleChildWidget>[];

    // Core services - always available, but check before adding
    _addCoreProvider<AuthService>(providers);
    _addCoreProvider<LocalOllamaConnectionService>(providers);
    _addCoreProvider<DesktopClientDetectionService>(providers);
    _addCoreProvider<AppInitializationService>(providers);
    _addCoreProvider<WebDownloadPromptService>(providers);
    _addCoreProvider<ProviderDiscoveryService>(providers);
    _addCoreProvider<LLMErrorHandler>(providers);
    _addCoreProvider<LangChainPromptService>(providers);
    _addCoreProvider<EnhancedUserTierService>(providers);
    _addCoreProvider<ThemeProvider>(providers);
    _addCoreProvider<ProviderConfigurationManager>(providers);
    _addCoreProvider<PlatformDetectionService>(providers);

    // PlatformAdapter - doesn't extend ChangeNotifier, so use Provider.value
    try {
      if (di.serviceLocator.isRegistered<PlatformAdapter>()) {
        final platformAdapter = di.serviceLocator.get<PlatformAdapter>();
        providers.add(
          Provider<PlatformAdapter>.value(value: platformAdapter),
        );
      }
    } catch (e, stack) {
      print('[Providers] Error adding PlatformAdapter: $e');
      print('[Providers] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
    }

    // Authenticated services - only provide if registered
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

  /// Helper method to safely add a core provider
  void _addCoreProvider<T extends ChangeNotifier>(
    List<SingleChildWidget> providers,
  ) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(
          ChangeNotifierProvider<T>.value(value: service),
        );
      } else {
        print('[Providers] Core service $T not registered yet');
      }
    } catch (e, stack) {
      print('[Providers] Error adding core provider $T: $e');
      print('[Providers] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
    }
  }

  /// Helper method to safely add a provider only if the service is registered
  void _addProviderIfRegistered<T extends ChangeNotifier>(
    List<SingleChildWidget> providers,
  ) {
    try {
      if (di.serviceLocator.isRegistered<T>()) {
        final service = di.serviceLocator.get<T>();
        providers.add(
          ChangeNotifierProvider<T>.value(value: service),
        );
      }
    } catch (e, stack) {
      print('[Providers] Error adding provider $T: $e');
      print('[Providers] Stack: $stack');
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    print('[AppRouterHost] initState called');
    // Initialize router after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      _initialized = true;
      _initializeRouterWhenReady();
    });
  }

  void _initializeRouterWhenReady() async {
    print('[AppRouterHost] _initializeRouterWhenReady called');
    final authService = context.read<AuthService>();
    print(
        '[AppRouterHost] isSessionBootstrapComplete: ${authService.isSessionBootstrapComplete}');

    if (authService.isSessionBootstrapComplete) {
      print('[AppRouterHost] Bootstrap already complete, initializing router');
      _initializeRouter(authService);
    } else {
      print('[AppRouterHost] Bootstrap not complete, waiting...');
      await authService.sessionBootstrapFuture;
      print('[AppRouterHost] Bootstrap completed, initializing router');
      if (!mounted) return;
      _initializeRouter(authService);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    try {
      // Get theme provider from context - use a safe accessor
      ThemeProvider? themeProvider;
      try {
        themeProvider = context.watch<ThemeProvider>();
      } catch (e) {
        print('[AppRouterHost] Warning: ThemeProvider not available: $e');
        // Continue without theme provider - will use defaults
      }

      return WindowListenerWidget(
        child: MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider?.themeMode ?? ThemeMode.system,
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
    } catch (e, stack) {
      print('[AppRouterHost] Error building router: $e');
      print('[AppRouterHost] Stack: $stack');
      Sentry.captureException(e, stackTrace: stack);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Router Error'),
                const SizedBox(height: 8),
                Text(e.toString()),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _initializeRouter(AuthService authService) {
    print('[AppRouterHost] _initializeRouter called');
    setState(() {
      _router = AppRouter.createRouter(
        navigatorKey: navigatorKey,
        authService: authService,
      );
      print('[AppRouterHost] Router created and set');
    });
  }
}
