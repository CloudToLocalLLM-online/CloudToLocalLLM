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
import 'services/provider_discovery_service.dart';
import 'services/streaming_chat_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/tunnel_service.dart';
import 'services/unified_connection_service.dart';
import 'services/user_container_service.dart';
import 'services/web_download_prompt_service.dart'
    if (dart.library.io) 'services/web_download_prompt_service_stub.dart';
import 'web_plugins_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'widgets/tray_initializer.dart';
import 'widgets/window_listener_widget.dart'
    if (dart.library.html) 'widgets/window_listener_widget_stub.dart';
import 'web_js_interop.dart'
    if (dart.library.io) 'web_js_interop_stub.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Future<AppBootstrapData> loadApp() async {
    // Handle Auth0 redirect callback on web before the app runs
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('code') &&
          uri.queryParameters.containsKey('state')) {
        try {
          // Ensure the dependency graph is ready before attempting to resolve services.
          await di.setupServiceLocator();
          await di.serviceLocator.allReady();

          final authService = di.serviceLocator.get<AuthService>();
          final success = await authService.handleRedirectCallback();

          // Clean the URL in the browser's history without a full reload.
          if (success) {
            history.replaceState(null, '', uri.path);
          }
        } catch (error, stackTrace) {
          debugPrint(
            '[Bootstrap] Failed to process Auth0 redirect callback: $error',
          );
          debugPrint('[Bootstrap] Stack trace: $stackTrace');
        }
      }
    }

    // Now, run the main bootstrap process
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

/// Main application widget with comprehensive loading screen
class CloudToLocalLLMApp extends StatefulWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<AppBootstrapData?>();
    if (bootstrap == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(message: 'Initializing CloudToLocalLLM...'),
      );
    }

    return MultiProvider(
      providers: _buildProviders(),
      child: TrayInitializer(
        navigatorKey: navigatorKey,
        child: const _AppRouterHost(),
      ),
    );
  }

  List<SingleChildWidget> _buildProviders() {
    return [
      ChangeNotifierProvider.value(value: di.serviceLocator.get<AuthService>()),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<EnhancedUserTierService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<TunnelService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<StreamingProxyService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<OllamaService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LocalOllamaConnectionService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<DesktopClientDetectionService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<AppInitializationService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<WebDownloadPromptService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<UserContainerService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<ProviderDiscoveryService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LangChainIntegrationService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LLMErrorHandler>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LLMProviderManager>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<ConnectionManagerService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LangChainPromptService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LangChainOllamaService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LangChainRAGService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<LLMAuditService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<StreamingChatService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<UnifiedConnectionService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<AdminService>(),
      ),
      ChangeNotifierProvider.value(
        value: di.serviceLocator.get<AdminDataFlushService>(),
      ),
    ];
  }
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) {
      return;
    }

    final authService = context.read<AuthService>();
    _router = AppRouter.createRouter(
      navigatorKey: navigatorKey,
      authService: authService,
    );
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

    return WindowListenerWidget(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,
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
}
