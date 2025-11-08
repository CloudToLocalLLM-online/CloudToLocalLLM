import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_window_stub.dart' if (dart.library.html) 'web_window_web.dart';

import '../components/modern_card.dart';
import '../components/model_download_manager.dart';
import '../components/tunnel_details_card.dart';

import '../components/settings_sidebar.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../config/theme_extensions.dart';

import '../services/auth_service.dart';

import '../services/ollama_service.dart';
import '../services/tunnel_service.dart';
import '../services/user_data_service.dart';
import '../services/version_service.dart';
import '../services/settings_preference_service.dart';
import '../utils/color_extensions.dart';

/// Unified Settings Screen for CloudToLocalLLM v3.3.1+
///
/// Redesigned settings interface that matches the chat interface layout
/// with a sidebar for settings sections and a main content area.
/// This provides a consistent user experience across the application.
class UnifiedSettingsScreen extends StatefulWidget {
  final String? initialSection;

  const UnifiedSettingsScreen({super.key, this.initialSection});

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  late String _selectedSectionId;
  bool _isSidebarCollapsed = false;
  bool _hasInitializedMobileLayout = false;
  bool _isProMode = false;
  final SettingsPreferenceService _settingsPreferenceService =
      SettingsPreferenceService();

  // Settings state
  String _selectedTheme = 'dark';
  bool _enableNotifications = true;
  bool _enableSystemTray = true;
  bool _startMinimized = false;


  // Error handling state
  String? _initializationError;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = widget.initialSection ?? 'general';
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      debugPrint('[Settings] Initializing settings screen...');
      await _loadSettings();
      _isProMode = await _settingsPreferenceService.isProMode();
      setState(() {
        _isInitialized = true;
      });
      debugPrint('[Settings] Settings screen initialized successfully');
    } catch (e) {
      debugPrint('[Settings] Failed to initialize settings: $e');
      setState(() {
        _initializationError = e.toString();
        _isInitialized = true; // Still mark as initialized to show error UI
      });
    }
  }

  Future<void> _loadSettings() async {
    // Load current settings from preferences/storage
    // This would typically load from a configuration service
    await Future.delayed(
      const Duration(milliseconds: 100),
    ); // Simulate async load
    setState(() {
      _selectedTheme = 'dark';
      _enableNotifications = true;
      _enableSystemTray = true;
      _startMinimized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state during initialization
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundMain,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state if initialization failed
    if (_initializationError != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundMain,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: AppTheme.spacingM),
              Text(
                'Settings initialization failed',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.spacingS),
              Text(
                _initializationError!,
                style: TextStyle(color: AppTheme.textColorLight),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacingM),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppConfig.mobileBreakpoint;

    // Auto-collapse sidebar on mobile (only once)
    if (isMobile && !_isSidebarCollapsed && !_hasInitializedMobileLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSidebarCollapsed = true;
            _hasInitializedMobileLayout = true;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient background (matching chat interface)
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              child: AppBar(
                title: const Text('Settings'),
                elevation: 0,
                backgroundColor: AppTheme.backgroundMain,
                foregroundColor: AppTheme.textColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/'),
                ),
                actions: [
                  _buildProModeToggle(),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Main settings interface (matching chat layout)
            Expanded(
              child: Row(
                children: [
                  // Settings sidebar (like conversation list)
                  if (!isMobile || !_isSidebarCollapsed)
                    SettingsSidebar(
                      sections: SettingsSidebar.defaultSections,
                      selectedSectionId: _selectedSectionId,
                      onSectionSelected: (sectionId) {
                        debugPrint(
                          '[Settings] Section selected: $sectionId',
                        );
                        setState(() {
                          _selectedSectionId = sectionId;
                        });
                        // Auto-collapse sidebar on mobile after selection
                        if (isMobile) {
                          setState(() {
                            _isSidebarCollapsed = true;
                          });
                        }
                      },
                      isCollapsed: false,
                    ),

                  // Main settings content area (like chat area)
                  Expanded(child: _buildSettingsContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProModeToggle() {
    return Tooltip(
      message: _isProMode ? 'Switch to Simple Mode' : 'Switch to Pro Mode',
      child: Row(
        children: [
          Text(_isProMode ? 'Pro' : 'Simple'),
          Switch(
            value: _isProMode,
            onChanged: (value) {
              setState(() {
                _isProMode = value;
              });
              _settingsPreferenceService.setProMode(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Container(
      color: AppTheme.backgroundMain,
      child: Column(
        children: [
          // Ensure content starts at the top and fills available space
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: AppTheme.spacingL,
                    right: AppTheme.spacingL,
                    top: AppTheme.spacingM,
                    bottom: AppTheme.spacingL,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppConfig.maxContentWidth,
                      minHeight:
                          constraints.maxHeight -
                          AppTheme.spacingL -
                          AppTheme.spacingM,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(),
                        SizedBox(height: AppTheme.spacingL),
                        _buildSectionContentWithErrorHandling(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final section = SettingsSidebar.defaultSections.firstWhere(
      (s) => s.id == _selectedSectionId,
    );

    return Row(
      children: [
        Icon(section.icon, color: AppTheme.primaryColor, size: 32),
        SizedBox(width: AppTheme.spacingM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            if (section.subtitle != null)
              Text(
                section.subtitle!,
                style: TextStyle(fontSize: 16, color: AppTheme.textColorLight),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionContentWithErrorHandling() {
    try {
      debugPrint(
        '[Settings] Building content for section: $_selectedSectionId',
      );
      return _buildSectionContent();
    } catch (e) {
      debugPrint('[Settings] Error building section content: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'Error loading section',
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              e.toString(),
              style: TextStyle(color: AppTheme.textColorLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedSectionId = 'general';
                });
              },
              child: const Text('Go to General'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSectionContent() {
    switch (_selectedSectionId) {
      case 'general':
        return _buildGeneralSettings();
      // Ensure 'tunnel-connection' maps to the LLM provider settings
      case 'tunnel-connection':
      case 'llm-provider':
        return _buildLLMProviderSettings();
      // Add a case for 'model-download-manager'
      case 'model-download-manager':
        return _buildModelDownloadManagerSettings();
      // Add a case for 'downloads' (web platform only)
      case 'downloads':
        return _buildDownloadsSettings();
      case 'data-management':
        return _buildDataManagementSettings();
      case 'about':
        return _buildAboutSettings();
      default:
        return _buildGeneralSettings();
    }
  }

  Widget _buildGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _optimizedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme setting (consolidated from Appearance)
              _buildSettingItem(
                'Theme',
                'Choose your preferred theme',
                DropdownButton<String>(
                  value: _selectedTheme,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    DropdownMenuItem(value: 'system', child: Text('System')),
                  ],
                  onChanged: (value) {
                    debugPrint('[Settings] Theme changed to: $value');
                    setState(() {
                      _selectedTheme = value ?? 'dark';
                    });
                  },
                ),
              ),
              const Divider(),
              _buildSettingItem(
                'Enable Notifications',
                'Show system notifications for important events',
                Switch(
                  value: _enableNotifications,
                  onChanged: (value) {
                    debugPrint(
                      '[Settings] Notifications toggled to: $value',
                    );
                    setState(() {
                      _enableNotifications = value;
                    });
                  },
                ),
              ),
              // Start minimized setting - Desktop only
              if (!kIsWeb && _isProMode) ...[
                const Divider(),
                _buildSettingItem(
                  'Start Minimized',
                  'Start application minimized to system tray',
                  Switch(
                    value: _startMinimized,
                    onChanged: (value) {
                      setState(() {
                        _startMinimized = value;
                      });
                    },
                  ),
                ),
              ],
              // System tray setting (consolidated from System Tray) - Desktop only
              if (!kIsWeb && _isProMode) ...[
                const Divider(),
                _buildSettingItem(
                  'Enable System Tray',
                  'Show CloudToLocalLLM icon in system tray',
                  Switch(
                    value: _enableSystemTray,
                    onChanged: (value) {
                      setState(() {
                        _enableSystemTray = value;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLLMProviderSettings() {
    // The existing kIsWeb logic correctly differentiates settings.
    // Renaming this section conceptually to "Tunnel Connection"
    // The UI will be structured by _buildWebLLMProviderSettings and _buildDesktopLLMProviderSettings
    if (kIsWeb) {
      return _buildWebLLMProviderSettings();
    } else {
      return _buildDesktopLLMProviderSettings();
    }
  }

  Widget _buildWebLLMProviderSettings() {
    // Simplified web tunnel connection settings
    return Column(
      children: [
        // Educational info about the tunnel proxy service
        _buildTunnelProxyInfoCard(),
        SizedBox(height: AppTheme.spacingM),

        // Connection Status Card
        _buildWebConnectionStatusCard(),
      ],
    );
  }

  Widget _buildDesktopLLMProviderSettings() {
    // This section now represents "Tunnel Connection" settings for desktop.
    // Prioritize setup wizard and streamline the UI
    try {
      final needsSetup = !Provider.of<AuthService>(
        context,
        listen: false,
      ).isAuthenticated.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Setup wizard for unauthenticated users
          if (needsSetup) ...[
            _optimizedCard(child: _buildSetupWizardContent()),
            SizedBox(height: AppTheme.spacingM),
          ],

          // Main tunnel status and controls
          _optimizedCard(
            child: Consumer<TunnelService>(
              builder: (context, tunnelService, child) {
                return _buildTunnelMainContent(tunnelService, needsSetup);
              },
            ),
          ),

          // Advanced settings (collapsible)
          if (!needsSetup) ...[
            SizedBox(height: AppTheme.spacingM),
            _optimizedCard(child: _buildTunnelAdvancedContent()),
          ],
        ],
      );
    } catch (e) {
      debugPrint('[Settings] Error building tunnel settings: $e');
      return _buildServiceErrorCard('Failed to load tunnel settings: $e');
    }
  }

  // New method to build the Model Download Manager section
  Widget _buildModelDownloadManagerSettings() {
    return Consumer<OllamaService>(
      builder: (context, ollamaService, child) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: ModelDownloadManager(isProMode: _isProMode),
          ),
        );
      },
    );
  }

  // New method to build the Downloads section (web platform only)
  Widget _buildDownloadsSettings() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDownloadsHeader(),
            SizedBox(height: AppTheme.spacingL),
            _buildWindowsDesktopDownload(),
            SizedBox(height: AppTheme.spacingL),
            _buildSystemRequirements(),
            SizedBox(height: AppTheme.spacingL),
            _buildInstallationInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsHeader() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Desktop Client Downloads',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Download the CloudToLocalLLM desktop client to connect your local Ollama instance to this web interface.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textColor),
          ),
          SizedBox(height: AppTheme.spacingS),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'The desktop client creates a secure tunnel between your local Ollama instance and this web interface.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsDesktopDownload() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download, color: AppTheme.secondaryColor, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Desktop Client Downloads',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Download the desktop application for your platform to connect your local Ollama instance.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
          ),
          SizedBox(height: AppTheme.spacingS),
          SizedBox(height: AppTheme.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // GitHub releases page with all platform downloads
                final url = AppConfig.githubReleasesUrl;
                _launchUrl(url);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download from GitHub Releases'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            'Download installers for Windows, Linux, and macOS from our GitHub releases page. Choose the appropriate package for your platform.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemRequirements() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, color: Colors.orange, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'System Requirements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimum Requirements:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                ...[
                  'OS: Windows 10 or later (64-bit)',
                  'Memory: 512MB RAM minimum, 1GB recommended',
                  'Storage: 200MB available space',
                  'Network: Internet connection for cloud proxy',
                ].map(
                  (req) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $req',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'For Local Ollama:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                ...[
                  'Ollama installed and running on localhost:11434',
                  'At least one Ollama model downloaded',
                  'Firewall configured to allow local connections',
                ].map(
                  (req) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $req',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallationInstructions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Installation Instructions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildInstructionStep(
            '1. Download the Desktop Client',
            'Choose either the portable .zip package or the .msi installer from the download section above.',
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildInstructionStep(
            '2. Install Ollama (if not already installed)',
            'Download and install Ollama from ollama.ai, then download at least one model (e.g., "ollama pull llama2").',
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildInstructionStep(
            '3. Run CloudToLocalLLM Desktop Client',
            'Launch the desktop application. It will automatically detect your local Ollama instance and create a secure tunnel.',
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildInstructionStep(
            '4. Connect from Web Interface',
            'Return to this web interface and authenticate. The desktop client will appear as connected, allowing you to chat with your local models.',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.spacingXS),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
        ),
      ],
    );
  }

  // Helper method to launch URLs
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildServiceErrorCard(String errorMessage) {
    return ModernCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 48, color: Colors.orange),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Service Error',
            style: TextStyle(
              color: AppTheme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            errorMessage,
            style: TextStyle(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSectionId = 'general';
              });
            },
            child: const Text('Go to General Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildTunnelProxyInfoCard() {
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'About CloudToLocalLLM Tunnel Service',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              kIsWeb
                  ? 'CloudToLocalLLM provides a secure tunnel proxy that connects this web interface to your local Ollama instance running on your desktop. No data is stored in the cloud - all processing happens locally on your machine.'
                  : 'CloudToLocalLLM creates a secure encrypted tunnel that allows web browsers and remote clients to access your local Ollama instance. The "cloud" component is just the proxy service that bridges connections - all your data and models remain local.',
              style: TextStyle(color: AppTheme.textColorLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingM),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildFeatureItem('✓ Secure tunnel proxy for web access'),
                  _buildFeatureItem('✓ Encrypted connection to local Ollama'),
                  _buildFeatureItem('✓ No cloud storage or data sync'),
                  _buildFeatureItem('✓ All processing stays on your device'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact version of tunnel info card - reduced size and content

  // Tunnel Setup Wizard Card - prioritized for new users

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: AppTheme.spacingM),
          Text(
            text,
            style: TextStyle(color: AppTheme.textColorLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    return Column(
      children: [
        ModernCard(
          child: FutureBuilder<String>(
            future: VersionService.instance.getFullVersion(),
            builder: (context, snapshot) {
              final version = snapshot.data ?? 'Loading...';
              return Column(
                children: [
                  Icon(Icons.info, size: 64, color: AppTheme.primaryColor),
                  SizedBox(height: AppTheme.spacingM),
                  Text(
                    'CloudToLocalLLM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Version $version',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textColorLight,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.',
                    style: TextStyle(color: AppTheme.textColorLight),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebConnectionStatusCard() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_sync,
                    color: isAuthenticated ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Cloud Tunnel Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  // View Logs button (web only)
                  if (kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () {
                        // Open console in a new window
                        web.open('javascript:console.clear();', 'logs');
                        // Show instructions in a dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('View Console Logs'),
                            content: const Text(
                              'To view application logs, open Developer Tools (F12) in your main browser window and check the Console tab.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('View Logs'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppTheme.spacingM),

              // Connection Status
              _buildStatusRow(
                'Connection',
                isAuthenticated ? 'Connected' : 'Disconnected',
                isAuthenticated ? Colors.green : Colors.red,
              ),

              // Tunnel Endpoint
              if (isAuthenticated)
                _buildStatusRow(
                  'Tunnel Endpoint',
                  '${AppConfig.apiBaseUrl}/tunnel/${authService.currentUser?.id ?? 'user'}',
                  AppTheme.textColorLight,
                ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppTheme.textColorLight),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, Widget control) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(flex: 1, child: control),
        ],
      ),
    );
  }

  // Desktop tunnel management methods

  // Helper methods for settings display

  /// Build data management settings section
  Widget _buildDataManagementSettings() {
    return Column(
      children: [
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.delete_sweep,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  const Text(
                    'Data Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingM),
              const Text(
                'Manage your personal data stored by CloudToLocalLLM. This includes conversations, authentication tokens, settings, and cached data.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              SizedBox(height: AppTheme.spacingL),

              // Clear All Data Section
              Container(
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: AppTheme.warningColor,
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.spacingS),
                        const Text(
                          'Clear All User Data',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingS),
                    const Text(
                      'This will permanently delete:\n'
                      '• All conversation history and chat messages\n'
                      '• Authentication tokens and login sessions\n'
                      '• Application settings and preferences\n'
                      '• Cached data and temporary files',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showDataClearConfirmation,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Clear All Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (_isProMode) ...[
                          SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.go('/admin/data-flush');
                              },
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('Admin Panel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show data clear confirmation dialog
  Future<void> _showDataClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Data'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete all your data including conversations, settings, and authentication tokens.',
            ),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _executeDataClear();
    }
  }

  /// Execute data clearing operation
  Future<void> _executeDataClear() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing data...'),
            ],
          ),
        ),
      );

      // Use the simple UserDataService for data clearing
      final userDataService = UserDataService();
      final results = await userDataService.clearAllUserData();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show results
      final successCount = results.values.where((success) => success).length;
      final totalCount = results.length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data clearing completed: $successCount/$totalCount operations successful',
            ),
            backgroundColor: successCount == totalCount
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Optimized card component that prevents unnecessary rebuilds
  Widget _optimizedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.27),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingL),
          child: child,
        ),
      ),
    );
  }

  /// Clean, simplified tunnel content methods
  Widget _buildSetupWizardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assistant, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: AppTheme.spacingM),
            Text(
              'Setup Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingM),
        Text(
          'Complete authentication to enable tunnel connection and access cloud features.',
          style: TextStyle(color: AppTheme.textColorLight, fontSize: 14),
        ),
        SizedBox(height: AppTheme.spacingL),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/setup'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.all(AppTheme.spacingM),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTunnelMainContent(
    TunnelService tunnelService,
    bool needsSetup,
  ) {
    final isConnected = tunnelService.isConnected;
    final error = tunnelService.error;

    if (_isProMode) {
      return TunnelDetailsCard(tunnelState: tunnelService.state);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status header
        Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.cloud_off,
              color: isConnected ? Colors.green : Colors.grey,
              size: 24,
            ),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tunnel Connection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  Text(
                    isConnected
                        ? 'Connected and active'
                        : error != null
                        ? 'Connection error'
                        : 'Disconnected',
                    style: TextStyle(
                      fontSize: 14,
                      color: isConnected
                          ? Colors.green[700]
                          : error != null
                          ? Colors.red[700]
                          : AppTheme.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (error != null) ...[
          SizedBox(height: AppTheme.spacingM),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              error,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        ],

        if (!needsSetup) ...[
          SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isConnected
                      ? () {
                          tunnelService.disconnect();
                        }
                      : () {
                          tunnelService.connect();
                        },
                  icon: Icon(isConnected ? Icons.link_off : Icons.link),
                  label: Text(isConnected ? 'Disconnect' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTunnelAdvancedContent() {
    if (!_isProMode) {
      return ExpansionTile(
        title: Text(
          'Advanced Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textColor,
          ),
        ),
        initiallyExpanded: _isProMode, // Expand if in Pro mode
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tunnel Endpoint',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundMain,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    AppConfig.tunnelChiselUrl,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textColorLight,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
