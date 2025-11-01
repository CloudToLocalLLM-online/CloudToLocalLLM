import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'desktop_client_detection_service.dart';

/// Service to manage when the web download prompt should be shown
/// This replaces the setup wizard for web users
class WebDownloadPromptService extends ChangeNotifier {
  final AuthService _authService;
  final DesktopClientDetectionService? _clientDetectionService;

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
    DesktopClientDetectionService? clientDetectionService,
  }) : _authService = authService,
       _clientDetectionService = clientDetectionService;

  /// Initialize the service
  Future<void> initialize() async {
    // Download prompt service is disabled - tunnel wizard provides download functionality
    debugPrint(
      '[WebDownloadPrompt] Service disabled - using tunnel wizard for downloads',
    );
    _isInitialized = true;
    _shouldShowPrompt = false;
    notifyListeners();
  }

  /// Save prompt state to storage
  Future<void> _savePromptState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;

      if (userId != null) {
        await prefs.setBool(
          'web_download_prompt_seen_$userId',
          _hasUserSeenPrompt,
        );
        debugPrint(
          '[WebDownloadPrompt] Saved state for user $userId: hasSeenPrompt=$_hasUserSeenPrompt',
        );
      }
    } catch (e) {
      debugPrint('[WebDownloadPrompt] Error saving prompt state: $e');
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    // Service disabled - no action needed
  }

  /// Handle client detection changes
  void _onClientDetectionChanged() {
    // Service disabled - no action needed
  }

  /// Check if the download prompt should be shown
  Future<void> _checkShouldShowPrompt() async {
    // Download prompt is disabled - tunnel wizard has download links
    // Users can access downloads through the tunnel wizard instead
    _shouldShowPrompt = false;
    debugPrint(
      '[WebDownloadPrompt] Download prompt disabled - use tunnel wizard for downloads',
    );
    notifyListeners();
  }

  /// Mark the prompt as seen by the user
  Future<void> markPromptSeen() async {
    _hasUserSeenPrompt = true;
    await _savePromptState();
    await _checkShouldShowPrompt();
    debugPrint('[WebDownloadPrompt] Prompt marked as seen');
  }

  /// Hide the prompt permanently
  Future<void> hidePrompt() async {
    _shouldShowPrompt = false;
    // Also mark as seen to prevent it from showing again
    if (!_hasUserSeenPrompt) {
      await markPromptSeen();
    }
    debugPrint('[WebDownloadPrompt] Prompt hidden permanently');
    notifyListeners();
  }

  /// Show the prompt from settings (always show, regardless of completion status)
  void showPromptFromSettings() {
    _shouldShowPrompt = true;
    debugPrint('[WebDownloadPrompt] Showing prompt from settings');
    notifyListeners();
  }

  /// Get prompt progress information
  Map<String, dynamic> getPromptProgress() {
    final hasConnectedClients =
        _clientDetectionService?.hasConnectedClients ?? false;

    return {
      'hasUserSeenPrompt': _hasUserSeenPrompt,
      'shouldShowPrompt': _shouldShowPrompt,
      'isFirstTimeUser': _isFirstTimeUser,
      'hasConnectedClients': hasConnectedClients,
      'isAuthenticated': _authService.isAuthenticated.value,
      'connectedClientCount':
          _clientDetectionService?.connectedClientCount ?? 0,
    };
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _clientDetectionService?.removeListener(_onClientDetectionChanged);
    super.dispose();
  }
}
