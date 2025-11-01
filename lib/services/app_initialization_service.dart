import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'connection_manager_service.dart';
import 'desktop_client_detection_service.dart';

/// Service that manages the initialization order of other services
/// Ensures services that require authentication are only initialized after login
class AppInitializationService extends ChangeNotifier {
  final AuthService _authService;
  bool _isInitialized = false;
  bool _isInitializing = false;

  AppInitializationService({
    required AuthService authService,
  }) : _authService = authService {
    // Listen for auth state changes
    _authService.addListener(_onAuthStateChanged);
    
    // If already authenticated, initialize immediately
    if (_authService.isAuthenticated.value) {
      _initializeServices();
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    if (_authService.isAuthenticated.value && !_isInitialized && !_isInitializing) {
      debugPrint(' [AppInit] User authenticated, initializing services...');
      _initializeServices();
    } else if (!_authService.isAuthenticated.value && _isInitialized) {
      debugPrint(' [AppInit] User logged out, resetting initialization state');
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Initialize services that require authentication
  Future<void> _initializeServices() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    notifyListeners();

    try {
      debugPrint(' [AppInit] Starting service initialization...');

      // Note: We can't access context here, so services need to be initialized
      // when this service is consumed by widgets that have access to context
      
      _isInitialized = true;
      debugPrint(' [AppInit]  Service initialization completed');
    } catch (e) {
      debugPrint(' [AppInit]  Service initialization failed: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Initialize services with context (called from widget)
  Future<void> initializeWithContext(BuildContext context) async {
    if (!_authService.isAuthenticated.value || _isInitialized) return;

    try {
      debugPrint(' [AppInit] Initializing services with context...');

      // Capture services before any async operations to avoid BuildContext async gap
      final connectionManager = context.read<ConnectionManagerService>();
      final DesktopClientDetectionService? clientDetection = 
          kIsWeb ? context.read<DesktopClientDetectionService>() : null;

      // Initialize connection manager
      await connectionManager.initialize();

      // Initialize desktop client detection (web only)
      if (kIsWeb && clientDetection != null) {
        await clientDetection.initialize();
      }

      debugPrint(' [AppInit]  Context-based initialization completed');
    } catch (e) {
      debugPrint(' [AppInit]  Context-based initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}
