import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'web_plugins_stub.dart' if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:async';
import 'screens/loading_screen.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/app_initialization_service.dart';
import 'services/auth_service.dart';
import 'services/auth0_service.dart';
import 'services/auth0_web_service.dart' if (dart.library.io) 'services/auth0_web_service_stub.dart';
import 'services/auth0_desktop_service.dart';
import 'services/enhanced_user_tier_service.dart';
import 'services/ollama_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/unified_connection_service.dart';
import 'services/tunnel_service.dart';
import 'services/local_ollama_connection_service.dart';
import 'services/connection_manager_service.dart';
import 'services/streaming_chat_service.dart';
import 'services/native_tray_service.dart' if (dart.library.html) 'services/native_tray_service_stub.dart';
import 'services/window_manager_service.dart' if (dart.library.html) 'services/window_manager_service_stub.dart';
import 'services/desktop_client_detection_service.dart';
import 'services/web_download_prompt_service.dart' if (dart.library.io) 'services/web_download_prompt_service_stub.dart';
import 'services/user_container_service.dart';
import 'services/admin_service.dart';
import 'services/admin_data_flush_service.dart';
import 'services/langchain_ollama_service.dart';
import 'services/langchain_prompt_service.dart';
import 'services/langchain_rag_service.dart';
import 'services/llm_provider_manager.dart';
import 'services/llm_audit_service.dart';
import 'services/provider_discovery_service.dart';
import 'services/langchain_integration_service.dart';
import 'services/llm_error_handler.dart';

import 'widgets/window_listener_widget.dart' if (dart.library.html) 'widgets/window_listener_widget_stub.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auth0 initialization
  // Auth0 is initialized automatically when the auth service is created
  // Consolidated CI/CD pipeline deployment test

  // Configure URL strategy for web to handle direct navigation
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Set up local error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // Still show default Flutter error UI/console output
    FlutterError.presentError(details);
    debugPrint('FlutterError: \'${details.exception}\'');
    if (details.stack != null) {
      debugPrint('Stack trace: ${details.stack}');
    }
  };

  // Run the app inside a guarded zone to catch uncaught async errors
  runZonedGuarded(() async {
    runApp(const CloudToLocalLLMApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

/// Main application widget with comprehensive loading screen
class CloudToLocalLLMApp extends StatefulWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  bool _isInitialized = false;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create router once during initialization
    _router = AppRouter.createRouter(navigatorKey: navigatorKey);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Show the UI immediately to prevent black screen
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Initialize system tray for desktop platforms in background
      if (!kIsWeb) {
        // Run system tray initialization asynchronously without blocking UI
        _initializeSystemTray();
      }
    } catch (e) {
      debugPrint(" [App] Error during app initialization: $e");
      // Still show the UI even if initialization fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initializeSystemTray() async {
    try {
      debugPrint("[SystemTray] Initializing native tray service...");

      // Initialize window manager service first
      final windowManager = WindowManagerService();
      await windowManager.initialize();

      // Note: Tray service will be initialized after providers are set up
      // This ensures all required services are available
    } catch (e, stackTrace) {
      debugPrint(" [SystemTray] Failed to initialize system tray: $e");
      debugPrint(" [SystemTray] Stack trace: $stackTrace");
    }
  }

  void _navigateToRoute(String route) {
    try {
      debugPrint(" [Navigation] Attempting to navigate to route: $route");

      // Try multiple approaches to get a valid context
      BuildContext? context = navigatorKey.currentContext;

      context ??= navigatorKey.currentState?.context;
      context ??= _getCurrentAppContext();

      if (context != null && context.mounted) {
        debugPrint(
          "[Navigation] Context available, executing navigation to: $route",
        );

        // Use post-frame callback to ensure navigation happens after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context!.mounted) {
              context.go(route);
              debugPrint(
                "[Navigation] Navigation command sent for route: $route",
              );
            } else {
              debugPrint(
                "[Navigation] Context no longer mounted for route: $route",
              );
            }
          } catch (e) {
            debugPrint(
              " [Navigation] Post-frame navigation error for $route: $e",
            );
          }
        });
      } else {
        debugPrint(
          "[Navigation] Cannot navigate to $route: no valid context available",
        );

        // Schedule retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _retryNavigation(route, 1);
        });
      }
    } catch (e, stackTrace) {
      debugPrint(" [Navigation] Error navigating to $route: $e");
      debugPrint(" [Navigation] Stack trace: $stackTrace");
    }
  }

  void _retryNavigation(String route, int attempt) {
    if (attempt > 3) {
      debugPrint("[Navigation] Max retry attempts reached for route: $route");
      return;
    }

    debugPrint("[Navigation] Retry attempt $attempt for route: $route");

    final context =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (context != null && context.mounted) {
      try {
        context.go(route);
        debugPrint("[Navigation] Retry successful for route: $route");
      } catch (e) {
        debugPrint(" [Navigation] Retry failed for $route: $e");
        Future.delayed(const Duration(milliseconds: 1000), () {
          _retryNavigation(route, attempt + 1);
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _retryNavigation(route, attempt + 1);
      });
    }
  }

  BuildContext? _getCurrentAppContext() {
    try {
      // Try to get context from the current widget tree
      return navigatorKey.currentState?.context;
    } catch (e) {
      debugPrint("[Navigation] Could not get alternative context: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
            providers: [
              // Authentication service
              ChangeNotifierProvider(create: (_) {
                final Auth0Service auth0Service = kIsWeb ? Auth0WebService() : Auth0DesktopService();
                return AuthService(auth0Service);
              }),
        // User tier service
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final tierService = EnhancedUserTierService(
              authService: authService,
            );
            // Initialize the tier service asynchronously
            tierService.initialize();
            return tierService;
          },
        ),
        // Tunnel Service
        ChangeNotifierProxyProvider<AuthService, TunnelService>(
          create: (context) => TunnelService(
            authService: context.read<AuthService>(),
          ),
          update: (context, authService, previous) =>
              previous ?? TunnelService(authService: authService),
        ),
        // Streaming proxy service
        ChangeNotifierProvider(
          create: (context) =>
              StreamingProxyService(authService: context.read<AuthService>()),
        ),
        // Ollama service
        ChangeNotifierProvider(
          create: (context) {
            final ollamaService = OllamaService(
              authService: context.read<AuthService>(),
            );
            // Initialize asynchronously
            ollamaService.initialize();
            return ollamaService;
          },
        ),
        // Local Ollama connection service (independent of tunnel)
        ChangeNotifierProvider(
          create: (context) {
            final localOllama = LocalOllamaConnectionService();
            // Initialize the local Ollama service asynchronously
            localOllama.initialize();
            return localOllama;
          },
        ),
        // Desktop client detection service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final clientDetection = DesktopClientDetectionService(
              authService: authService,
            );
            // Don't initialize immediately - let it initialize after auth
            return clientDetection;
          },
        ),

        // App initialization service (manages service startup order)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            return AppInitializationService(authService: authService);
          },
        ),

        // Web download prompt service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final clientDetection = context
                .read<DesktopClientDetectionService>();
            final webDownloadPrompt = WebDownloadPromptService(
              authService: authService,
              clientDetectionService: clientDetection,
            );
            // Initialize the service asynchronously
            webDownloadPrompt.initialize();
            return webDownloadPrompt;
          },
        ),

        // User container service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            return UserContainerService(authService: authService);
          },
        ),

        // Provider Discovery Service
        ChangeNotifierProvider(
          create: (context) => ProviderDiscoveryService(),
        ),

        // LangChain Integration Service
        ChangeNotifierProvider(
          create: (context) {
            final discoveryService = context.read<ProviderDiscoveryService>();
            return LangChainIntegrationService(discoveryService: discoveryService);
          },
        ),

        // LLM Error Handler
        ChangeNotifierProvider(
          create: (context) {
            final discoveryService = context.read<ProviderDiscoveryService>();
            return LLMErrorHandler(providerDiscovery: discoveryService);
          },
        ),

        // LLM Provider Manager
        ChangeNotifierProvider(
          create: (context) {
            final discoveryService = context.read<ProviderDiscoveryService>();
            final langchainService = context.read<LangChainIntegrationService>();
            final providerManager = LLMProviderManager(
              discoveryService: discoveryService,
              langchainService: langchainService,
            );
            // Initialize asynchronously
            providerManager.initialize();
            return providerManager;
          },
        ),

        // Connection manager service (coordinates local and cloud)
        ChangeNotifierProvider(
          create: (context) {
            final localOllama = context.read<LocalOllamaConnectionService>();
            final tunnelService = context.read<TunnelService>();
            final authService = context.read<AuthService>();
            final connectionManager = ConnectionManagerService(
              localOllama: localOllama,
              tunnelService: tunnelService,
              authService: authService,
            );
            // Don't initialize immediately - let it initialize after auth
            return connectionManager;
          },
        ),

        // LangChain Prompt Service
        ChangeNotifierProvider(create: (_) => LangChainPromptService()),

        // LangChain Ollama Service
        ChangeNotifierProvider(
          create: (context) {
            final connectionManager = context.read<ConnectionManagerService>();
            final langchainOllama = LangChainOllamaService(
              connectionManager: connectionManager,
            );
            // Initialize asynchronously
            langchainOllama.initialize();
            return langchainOllama;
          },
        ),

        // LangChain RAG Service
        ChangeNotifierProvider(
          create: (context) {
            final langchainOllama = context.read<LangChainOllamaService>();
            final ragService = LangChainRAGService(
              ollamaService: langchainOllama,
            );
            // Initialize asynchronously
            ragService.initialize();
            return ragService;
          },
        ),

        // LLM Audit Service
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final auditService = LLMAuditService(authService: authService);
            // Initialize asynchronously
            auditService.initialize();
            return auditService;
          },
        ),

        // Streaming chat service (uses connection manager)
        ChangeNotifierProvider(
          create: (context) {
            final connectionManager = context.read<ConnectionManagerService>();
            final authService = context.read<AuthService>();
            return StreamingChatService(connectionManager, authService);
          },
        ),
        // Unified connection service (depends on connection manager)
        ChangeNotifierProvider(
          create: (context) {
            final unifiedService = UnifiedConnectionService();
            final connectionManager = context.read<ConnectionManagerService>();
            unifiedService.setConnectionManager(connectionManager);
            // Initialize the unified connection service
            unifiedService.initialize();
            return unifiedService;
          },
        ),
        // Admin service (requires authentication)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            return AdminService(authService: authService);
          },
        ),
        // Admin data flush service (requires authentication)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            return AdminDataFlushService(authService: authService);
          },
        ),
      ],
      child: MaterialApp(
        // App configuration
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,

        // Theme configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,

        // Show loading screen until initialization is complete
        home: _isInitialized
            ? _buildMainApp()
            : const LoadingScreen(message: 'Initializing CloudToLocalLLM...'),
      ),
    );
        } else {
          return const LoadingScreen(message: 'Initializing CloudToLocalLLM...');
        }
      }
    );
  }

        

  bool _trayInitialized = false;

  /// Initialize tray service after providers are available
  Future<void> _initializeTrayService(BuildContext context) async {
    if (_trayInitialized) return;
    _trayInitialized = true;

    // Only initialize on desktop platforms
    if (kIsWeb) {
      debugPrint(
        "[SystemTray] Skipping tray initialization on web platform",
      );
      return;
    }

    try {
      debugPrint("[SystemTray] Initializing native tray service...");

      // Get services from providers
      final connectionManager = context.read<ConnectionManagerService>();
      final localOllama = context.read<LocalOllamaConnectionService>();

      // Get window manager service
      final windowManager = WindowManagerService();

      // Initialize native tray service
      final nativeTray = NativeTrayService();
      final success = await nativeTray.initialize(
        connectionManager: connectionManager,
        localOllama: localOllama,
        onShowWindow: () {
          debugPrint("[SystemTray] Native tray requested to show window");
          windowManager.showWindow();
        },
        onHideWindow: () {
          debugPrint("� [SystemTray] Native tray requested to hide window");
          windowManager.hideToTray();
        },
        onSettings: () {
          debugPrint("[SystemTray] Native tray requested to open settings");
          _navigateToRoute('/settings');
        },
        onQuit: () {
          debugPrint(
            "[SystemTray] Native tray requested to quit application",
          );
          windowManager.forceClose();
        },
      );

      if (success) {
        debugPrint(
          "[SystemTray] Native tray service initialized successfully",
        );
      } else {
        debugPrint("[SystemTray] Failed to initialize native tray service");
      }
    } catch (e, stackTrace) {
      debugPrint(" [SystemTray] Failed to initialize system tray: $e");
      debugPrint(" [SystemTray] Stack trace: $stackTrace");
    }
  }

  Widget _buildMainApp() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Initialize tray service after providers are available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeTrayService(context);
        });

        return WindowListenerWidget(
          child: MaterialApp.router(
            // App configuration
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,

            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: AppConfig.enableDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,

            // Router configuration
            routerConfig: _router,

            // Builder for additional configuration
            builder: (context, child) {
              return MediaQuery(
                // Ensure text scaling doesn't break the UI
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(
                      context,
                    ).textScaler.scale(1.0).clamp(0.8, 1.2),
                  ),
                ),
                child: child!,
              );
            },
          ),
        );
      },
    );
  }
}
