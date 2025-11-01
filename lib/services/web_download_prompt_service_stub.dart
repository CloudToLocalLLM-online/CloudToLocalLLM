// Stub for WebDownloadPromptService on non-web platforms
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'desktop_client_detection_service.dart';

/// Stub implementation for desktop/mobile platforms
class WebDownloadPromptService extends ChangeNotifier {
  final AuthService _authService;

  bool _shouldShowPrompt = false;
  final bool _isFirstTimeUser = false;
  bool _hasUserSeenPrompt = false;
  bool _isInitialized = false;

  // Getters
  bool get shouldShowPrompt => _shouldShowPrompt;
  bool get isFirstTimeUser => _isFirstTimeUser;
  bool get hasUserSeenPrompt => _hasUserSeenPrompt;
  bool get isInitialized => _isInitialized;

  WebDownloadPromptService({
    required AuthService authService,
    required DesktopClientDetectionService clientDetectionService,
  }) : _authService = authService;

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('🌐 [WebDownloadPrompt] Service disabled on desktop platform');
    _isInitialized = true;
    _shouldShowPrompt = false;
    notifyListeners();
  }

  /// Mark the prompt as seen by the user
  Future<void> markPromptSeen() async {
    _hasUserSeenPrompt = true;
    _shouldShowPrompt = false;
    debugPrint('🌐 [WebDownloadPrompt] Prompt marked as seen (desktop stub)');
    notifyListeners();
  }

  /// Hide the prompt permanently
  Future<void> hidePrompt() async {
    _shouldShowPrompt = false;
    if (!_hasUserSeenPrompt) {
      await markPromptSeen();
    }
    debugPrint('🌐 [WebDownloadPrompt] Prompt hidden (desktop stub)');
    notifyListeners();
  }

  /// Show the prompt from settings
  void showPromptFromSettings() {
    // No-op on desktop
    debugPrint('🌐 [WebDownloadPrompt] Show prompt disabled on desktop');
  }

  /// Get prompt progress information
  Map<String, dynamic> getPromptProgress() {
    return {
      'hasUserSeenPrompt': _hasUserSeenPrompt,
      'shouldShowPrompt': false,
      'isFirstTimeUser': false,
      'hasConnectedClients': false,
      'isAuthenticated': _authService.isAuthenticated.value,
      'connectedClientCount': 0,
    };
  }
}

