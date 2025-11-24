import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/platform_adapter.dart';

/// Loading screen with unified theming and platform adaptation
///
/// Requirements:
/// - 9.1: Apply unified theme system to all UI elements
/// - 9.2: Display platform-appropriate loading indicator
/// - 9.3: Display status messages clearly
/// - 9.4: Adapt layout for different screen sizes
/// - 9.5: Display during initial app load to prevent black screen
/// - 13.1-13.3: Responsive design for mobile, tablet, desktop
/// - 14.1-14.6: Accessibility features
class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    final platformAdapter = Provider.of<PlatformAdapter>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing based on screen width
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    final double logoSize = isMobile ? 60 : (isTablet ? 70 : 80);
    final double indicatorSize = isMobile ? 32 : (isTablet ? 36 : 40);
    final double spacing = isMobile ? 16 : (isTablet ? 20 : 24);
    final double fontSize = isMobile ? 14 : (isTablet ? 15 : 16);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Semantics(
        label: 'Loading screen',
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo or loading indicator
                Semantics(
                  label: 'Application logo',
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.cloud_download_outlined,
                      color: theme.colorScheme.onPrimary,
                      size: logoSize * 0.5,
                    ),
                  ),
                ),

                SizedBox(height: spacing * 1.5),

                // Platform-appropriate loading indicator
                Semantics(
                  label: 'Loading indicator',
                  child: SizedBox(
                    width: indicatorSize,
                    height: indicatorSize,
                    child: platformAdapter.buildLoadingIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                SizedBox(height: spacing),

                // Loading message with proper typography
                Semantics(
                  label: 'Loading status: $message',
                  child: Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: fontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
