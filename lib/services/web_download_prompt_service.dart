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
  bool _isFirstTimeUser = false;
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
    if (!kIsWeb) {
      debugPrint('🌐 [WebDownloadPrompt] Skipping on non-web platform');
      _isInitialized = true;
      return;
    }

    try {
      // Load stored prompt state
      await _loadPromptState();

      // Listen to authentication changes
      _authService.addListener(_onAuthStateChanged);

      // Listen to client detection changes if available
      _clientDetectionService?.addListener(_onClientDetectionChanged);

      // Check initial state
      await _checkShouldShowPrompt();

      _isInitialized = true;
      debugPrint(
        '🌐 [WebDownloadPrompt] Web download prompt service initialized',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('🌐 [WebDownloadPrompt] Error initializing service: $e');
    }
  }

  /// Load prompt state from storage
  Future<void> _loadPromptState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;

      if (userId != null) {
        _hasUserSeenPrompt =
            prefs.getBool('web_download_prompt_seen_$userId') ?? false;
        debugPrint(
          '🌐 [WebDownloadPrompt] Loaded state for user $userId: hasSeenPrompt=$_hasUserSeenPrompt',
        );
      }
    } catch (e) {
      debugPrint('🌐 [WebDownloadPrompt] Error loading prompt state: $e');
      _hasUserSeenPrompt = false;
    }
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
          '🌐 [WebDownloadPrompt] Saved state for user $userId: hasSeenPrompt=$_hasUserSeenPrompt',
        );
      }
    } catch (e) {
      debugPrint('🌐 [WebDownloadPrompt] Error saving prompt state: $e');
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    debugPrint(
      '🌐 [WebDownloadPrompt] Auth state changed: ${_authService.isAuthenticated.value}',
    );

    if (_authService.isAuthenticated.value) {
      // User just logged in, check if they're a first-time user
      _checkIfFirstTimeUser();
      _checkShouldShowPrompt();
    } else {
      // User logged out, reset prompt state
      _shouldShowPrompt = false;
      _isFirstTimeUser = false;
      notifyListeners();
    }
  }

  /// Handle client detection changes
  void _onClientDetectionChanged() {
    debugPrint(
      '🌐 [WebDownloadPrompt] Client detection changed: ${_clientDetectionService?.hasConnectedClients}',
    );
    _checkShouldShowPrompt();
  }

  /// Check if the user is logging in for the first time
  void _checkIfFirstTimeUser() {
    // For now, we'll consider a user first-time if they haven't seen the prompt
    // In a real implementation, you might check Auth0 metadata or user creation date
    _isFirstTimeUser = !_hasUserSeenPrompt;

    // Additional check: if user is authenticated and we haven't loaded their state yet
    if (_authService.isAuthenticated.value && !_hasUserSeenPrompt) {
      // This could be enhanced to check Auth0 user metadata for actual first login
      // For example: user.metadata?.firstLogin or user.createdAt comparison
      _isFirstTimeUser = true;
    }

    debugPrint(
      '🌐 [WebDownloadPrompt] First time user: $_isFirstTimeUser (hasSeenPrompt: $_hasUserSeenPrompt)',
    );
  }

  /// Check if the download prompt should be shown
  Future<void> _checkShouldShowPrompt() async {
    // Only show on web platform
    if (!kIsWeb || !_authService.isAuthenticated.value) {
      _shouldShowPrompt = false;
      notifyListeners();
      return;
    }

    final hasConnectedClients =
        _clientDetectionService?.hasConnectedClients ?? false;

    // Show prompt only if:
    // 1. User is first-time AND hasn't seen the prompt yet
    // 2. OR no clients are connected (to encourage desktop app download)
    final shouldShow =
        (_isFirstTimeUser && !_hasUserSeenPrompt) || !hasConnectedClients;

    if (_shouldShowPrompt != shouldShow) {
      _shouldShowPrompt = shouldShow;
      debugPrint(
        '🌐 [WebDownloadPrompt] Should show prompt: $_shouldShowPrompt (firstTime: $_isFirstTimeUser, hasSeenPrompt: $_hasUserSeenPrompt, hasClients: $hasConnectedClients)',
      );
      notifyListeners();
    }
  }

  /// Mark the prompt as seen by the user
  Future<void> markPromptSeen() async {
    _hasUserSeenPrompt = true;
    await _savePromptState();
    await _checkShouldShowPrompt();
    debugPrint('🌐 [WebDownloadPrompt] Prompt marked as seen');
  }

  /// Hide the prompt
  void hidePrompt() {
    _shouldShowPrompt = false;
    debugPrint('🌐 [WebDownloadPrompt] Prompt hidden');
    notifyListeners();
  }

  /// Show the prompt from settings (always show, regardless of completion status)
  void showPromptFromSettings() {
    _shouldShowPrompt = true;
    debugPrint('🌐 [WebDownloadPrompt] Showing prompt from settings');
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
