import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/ollama_service.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../services/platform_detection_service.dart';
import '../services/platform_adapter.dart';

class OllamaTestScreen extends StatefulWidget {
  const OllamaTestScreen({super.key});

  @override
  State<OllamaTestScreen> createState() => _OllamaTestScreenState();
}

class _OllamaTestScreenState extends State<OllamaTestScreen> {
  late OllamaService _ollamaService;
  final TextEditingController _messageController = TextEditingController();
  String? _selectedModel;
  String? _chatResponse;

  @override
  void initState() {
    super.initState();
    _ollamaService = OllamaService();
    _testConnection();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _ollamaService.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final connected = await _ollamaService.testConnection();
    if (connected) {
      await _ollamaService.getModels();
      if (_ollamaService.models.isNotEmpty) {
        setState(() {
          _selectedModel = _ollamaService.models.first.name;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _selectedModel == null) return;

    final response = await _ollamaService.chat(
      model: _selectedModel!,
      message: _messageController.text,
    );

    setState(() {
      _chatResponse = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final platformService = Provider.of<PlatformDetectionService>(context);
    final platformAdapter = Provider.of<PlatformAdapter>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive layout breakpoints
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama Test'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        leading: platformAdapter.buildBackButton(
          context,
          onPressed: () {
            // Explicit back navigation
            if (context.canPop()) {
              context.pop();
            } else {
              // Fallback to home if no navigation stack
              context.go('/');
            }
          },
        ),
        actions: [
          // Back to Home button (hide on mobile)
          if (!isMobile) ...[
            platformAdapter.buildButton(
              context,
              onPressed: () => context.go('/'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.home, size: 20),
                  SizedBox(width: 4),
                  Text('Home'),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return platformAdapter.buildButton(
                context,
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, size: 20),
                    if (!isMobile) ...[
                      const SizedBox(width: 4),
                      Text(authService.currentUser?.name ?? 'Logout'),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Authentication Status
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return Card(
                      color: theme.cardTheme.color,
                      elevation: theme.cardTheme.elevation ?? 1,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Authentication Status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Row(
                              children: [
                                Icon(
                                  authService.isAuthenticated.value
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: authService.isAuthenticated.value
                                      ? Colors.green
                                      : Colors.red,
                                  size: isMobile ? 20 : 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authService.isAuthenticated.value
                                        ? 'Authenticated as ${authService.currentUser?.email ?? "Unknown"}'
                                        : 'Not authenticated',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isMobile ? 12 : 16),

                // Ollama Connection Status
                ListenableBuilder(
                  listenable: _ollamaService,
                  builder: (context, child) {
                    return Card(
                      color: theme.cardTheme.color,
                      elevation: theme.cardTheme.elevation ?? 1,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ollama Connection',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Row(
                              children: [
                                Icon(
                                  _ollamaService.isConnected
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _ollamaService.isConnected
                                      ? Colors.green
                                      : Colors.red,
                                  size: isMobile ? 20 : 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _ollamaService.isConnected
                                        ? 'Connected (v${_ollamaService.version})'
                                        : 'Not connected',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_ollamaService.error != null) ...[
                              SizedBox(height: isMobile ? 6 : 8),
                              Text(
                                'Error: ${_ollamaService.error}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            SizedBox(height: isMobile ? 10 : 12),
                            SizedBox(
                              width: double.infinity,
                              height: isMobile ? 44 : 48,
                              child: platformAdapter.buildButton(
                                context,
                                onPressed: _ollamaService.isLoading
                                    ? null
                                    : _testConnection,
                                child: _ollamaService.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Test Connection'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isMobile ? 12 : 16),

                // Models List
                ListenableBuilder(
                  listenable: _ollamaService,
                  builder: (context, child) {
                    if (_ollamaService.models.isEmpty) {
                      return Card(
                        color: theme.cardTheme.color,
                        elevation: theme.cardTheme.elevation ?? 1,
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                          child: Text(
                            'No models available. Make sure Ollama is running and has models installed.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }

                    return Card(
                      color: theme.cardTheme.color,
                      elevation: theme.cardTheme.elevation ?? 1,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Models (${_ollamaService.models.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: isMobile ? 10 : 12),
                            DropdownButtonFormField<String>(
                              value: _selectedModel,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: _ollamaService.models.map((model) {
                                return DropdownMenuItem(
                                  value: model.name,
                                  child: Text(
                                    '${model.displayName} (${model.sizeFormatted})',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedModel = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isMobile ? 12 : 16),

                // Chat Test
                if (_selectedModel != null) ...[
                  Card(
                    color: theme.cardTheme.color,
                    elevation: theme.cardTheme.elevation ?? 1,
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Chat',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: isMobile ? 10 : 12),
                          TextField(
                            controller: _messageController,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter a message to test the model...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            maxLines: isMobile ? 3 : 2,
                          ),
                          SizedBox(height: isMobile ? 10 : 12),
                          SizedBox(
                            width: double.infinity,
                            height: isMobile ? 44 : 48,
                            child: platformAdapter.buildButton(
                              context,
                              onPressed: _ollamaService.isLoading
                                  ? null
                                  : _sendMessage,
                              child: _ollamaService.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Send Message'),
                            ),
                          ),
                          if (_chatResponse != null) ...[
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'Response:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isMobile ? 10 : 12),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _chatResponse!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: isMobile
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                // Explicit navigation back to home
                context.go('/');
              },
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
              tooltip: 'Return to main application',
              backgroundColor: theme.floatingActionButtonTheme.backgroundColor,
              foregroundColor: theme.floatingActionButtonTheme.foregroundColor,
            ),
    );
  }
}
