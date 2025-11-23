# Platform Settings Screen Design Document

## Overview

The Platform Settings Screen is a comprehensive, unified settings interface that consolidates user preferences, local LLM provider configuration, and administrative access into a single, platform-adaptive screen. This design implements all 14 requirements including the new Admin Center access feature. The screen leverages existing services (`ProviderConfigurationManager`, `SettingsPreferenceService`, `PlatformDetectionService`, `AuthService`) while adding new UI components and orchestration logic to present settings in a user-friendly, platform-appropriate manner.

## Architecture

### Component Hierarchy

```
UnifiedSettingsScreen (Main Container)
├── SettingsAppBar (Platform-adaptive header)
├── SettingsSearchBar (Search & filter)
├── SettingsCategoryList (Category navigation)
│   ├── GeneralSettingsCategory
│   ├── LocalLLMProvidersCategory
│   ├── AccountSettingsCategory
│   │   └── AdminCenterButton (visible only for admin users)
│   ├── PrivacySettingsCategory
│   ├── PremiumFeaturesCategory (Premium users only)
│   ├── DesktopSettingsCategory (Windows only)
│   ├── MobileSettingsCategory (iOS/Android only)
│   └── AdminCenterCategory (Admin users only)
└── SettingsContentPanel (Active category content)
```

### Data Flow

```
UnifiedSettingsScreen
    ↓
[Platform Detection]
    ↓
[Admin Status Check]
    ↓
[Load Existing Services]
    ├── ProviderConfigurationManager
    ├── SettingsPreferenceService
    ├── AuthService
    └── PlatformDetectionService
    ↓
[Filter Categories by Platform & Role]
    ↓
[Render UI]
    ↓
[User Interaction]
    ↓
[Validate & Save]
    ↓
[Update Services]
```

## Components and Interfaces

### 1. UnifiedSettingsScreen (Main Container)

**Responsibility:** Orchestrates the entire settings experience, manages category navigation, and coordinates with existing services.

**Key Features:**
- Platform detection and category filtering
- Admin status detection and role-based visibility
- Search functionality across all settings
- Category-based navigation
- Responsive layout (single column mobile, multi-column desktop)
- Admin access detection and navigation

**State Management:**
- Active category tracking
- Search query state
- Validation error state
- Loading state for async operations
- Admin status state

**Integration Points:**
- `AuthService` - Get current user, admin status, and handle logout
- `PlatformDetectionService` - Detect platform
- `ProviderConfigurationManager` - Access provider configs
- `SettingsPreferenceService` - Access user preferences
- `NavigationService` - Handle navigation to Admin Center

### 2. SettingsSearchBar

**Responsibility:** Provides real-time search across all settings categories.

**Features:**
- Text input with clear button
- Real-time filtering (300ms debounce)
- Highlights matching settings
- Shows result count
- Keyboard support (Escape to clear)

**Search Scope:**
- Category titles
- Setting names
- Setting descriptions
- Provider names

### 3. SettingsCategoryList

**Responsibility:** Displays available settings categories based on platform, subscription tier, and user role.

**Categories:**

**General Settings**
- Theme selection (Light, Dark, System)
- Language selection
- Startup behavior (Windows only)

**Local LLM Providers**
- List of configured providers
- Add/remove provider buttons
- Test connection button
- Default provider selection
- Default model selection

**Account Settings**
- User email display
- Subscription tier display
- Login time and token expiration
- Logout button
- Admin Center button (admin users only)
- Upgrade to Premium button (free users only)

**Privacy Settings**
- Analytics toggle
- Crash reporting toggle
- Usage statistics toggle
- Clear data button

**Premium Features (Premium users only)**
- Placeholder message for coming soon features
- Framework for future cloud integration

**Desktop Settings (Windows & Linux)**
- Launch on startup toggle
- Minimize to tray toggle (Windows only)
- Always on top toggle
- Remember window position toggle
- Remember window size toggle

**Mobile Settings (iOS/Android only)**
- Biometric authentication toggle
- Notifications toggle
- Notification sound toggle
- Vibration toggle

**Admin Center (Admin users only)**
- Admin Center access button
- Link to admin dashboard

### 4. SettingsContentPanel

**Responsibility:** Renders the content for the active category.

**Features:**
- Smooth transitions between categories
- Form validation with inline errors
- Save/cancel buttons
- Success/error notifications
- Loading states for async operations

### 5. AdminCenterButton

**Responsibility:** Provides access to the Admin Center for authenticated admin users.

**Features:**
- Visible only for admin users
- Keyboard accessible (Tab, Enter)
- Visible focus indicator
- ARIA label for screen readers
- Error handling for invalid/unreachable URLs
- Session token passing for authentication

**Integration:**
- Uses `AuthService` to check admin status
- Uses `NavigationService` to navigate to Admin Center URL
- Passes current session token for authentication

### 6. ProviderConfigurationUI

**Responsibility:** Manages the UI for adding/editing local LLM provider configurations.

**Features:**
- Provider type dropdown (Ollama, LM Studio, LocalAI, etc.)
- Host URL input with validation
- Port input with validation
- Optional API key input
- Test connection button with status feedback
- Available models display
- Enable/disable toggle

**Integration:**
- Uses existing `ProviderConfigurationManager`
- Validates against `ProviderConfiguration` model
- Tests connections via `LangChainIntegrationService`

## Data Models

### Settings Structure

The screen works with existing models and adds minimal new state:

```dart
class SettingsUIState {
  // Navigation
  String activeCategory;
  String searchQuery;
  
  // Validation
  Map<String, String> fieldErrors;
  
  // Loading
  bool isLoading;
  bool isSaving;
  
  // Admin
  bool isAdminUser;
  
  // Subscription
  String subscriptionTier; // 'Free' or 'Premium'
}
```

### Category Definition

```dart
class SettingsCategory {
  final String id;
  final String title;
  final IconData icon;
  final bool isVisible; // Platform/role dependent
  final WidgetBuilder contentBuilder;
}
```

## Platform Adaptation Strategy

### Platform Detection

Uses `PlatformDetectionService` to determine:
- `isWeb` - Flutter web platform
- `isWindows` - Windows desktop
- `isLinux` - Linux desktop
- `isAndroid` - Android mobile
- `isIOS` - iOS mobile

### Category Visibility

```dart
List<SettingsCategory> getVisibleCategories() {
  final categories = [
    // Always visible
    generalCategory,
    localLLMCategory,
    accountCategory,
    privacyCategory,
    
    // Subscription-based
    if (subscriptionTier == 'Premium') premiumFeaturesCategory,
    
    // Platform-specific
    if (platformService.isWindows || platformService.isLinux) desktopCategory,
    if (platformService.isMobile) mobileCategory,
    
    // Role-specific
    if (isAdminUser) adminCenterCategory,
  ];
  return categories;
}
```

### UI Component Selection

```dart
Widget buildSettingInput(String type) {
  if (platformService.isWeb) {
    return MaterialSettingInput(type);
  } else if (platformService.isIOS) {
    return CupertinoSettingInput(type);
  } else if (platformService.isWindows || platformService.isLinux) {
    return DesktopSettingInput(type);
  } else {
    return MaterialSettingInput(type);
  }
}
```

## Error Handling

### Validation Errors

- Inline error messages below fields
- Field highlighting (red border)
- Prevent save until errors resolved
- Clear errors on successful save

### Persistence Errors

- Toast notification with error message
- Retry button
- Fallback to in-memory storage if needed

### Connection Errors

- Timeout after 5 seconds
- Display user-friendly error message
- Suggest troubleshooting steps

### Admin Center Navigation Errors

- Display user-friendly error message if URL is invalid
- Provide retry option
- Suggest contacting support if issue persists

## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Platform Detection Timing
*For any* settings screen initialization, platform detection SHALL complete within 100 milliseconds
**Validates: Requirements 1.1**

### Property 2: Web Platform Category Filtering
*For any* settings screen running on web platform, desktop-specific and mobile-specific categories SHALL be hidden
**Validates: Requirements 1.2**

### Property 3: Windows Platform Category Display
*For any* settings screen running on Windows platform, all desktop-specific categories SHALL be displayed
**Validates: Requirements 1.3**

### Property 4: Mobile Platform Category Display
*For any* settings screen running on mobile platform, mobile-specific categories SHALL be displayed and desktop-specific options SHALL be hidden
**Validates: Requirements 1.4**

### Property 5: Platform-Appropriate UI Components
*For any* settings screen, the rendered UI components SHALL match the platform (Material for web/Android, Cupertino for iOS, native for Windows)
**Validates: Requirements 1.5**

### Property 6: Cross-Platform Settings Compatibility
*For any* settings saved on one platform, those settings SHALL be loadable and compatible on another platform
**Validates: Requirements 1.6**

### Property 7: Theme Application Timing
*For any* theme selection, the Theme_Manager SHALL apply the new theme within 200 milliseconds
**Validates: Requirements 2.2**

### Property 8: Windows Startup Behavior Visibility
*For any* settings screen running on Windows platform, startup behavior options SHALL be displayed
**Validates: Requirements 2.4**

### Property 9: Mobile-Specific Options Visibility
*For any* settings screen running on mobile platform, biometric and notification options SHALL be displayed
**Validates: Requirements 2.5**

### Property 10: General Settings Persistence Timing
*For any* general settings change, the Settings_Service SHALL persist the change within 500 milliseconds
**Validates: Requirements 2.6**

### Property 11: Multiple Provider Support
*For any* local LLM provider configuration, the system SHALL support adding multiple LangChain-compatible providers
**Validates: Requirements 3.3**

### Property 12: Provider Test Connection Timing
*For any* provider test connection request, the Settings_Service SHALL validate the connection within 5 seconds
**Validates: Requirements 3.6**

### Property 13: Unified Model List
*For any* configured providers, the Settings_Screen SHALL display a unified list containing models from all providers
**Validates: Requirements 3.7**

### Property 14: Provider Enable/Disable Idempotence
*For any* provider, toggling enable/disable SHALL not remove the provider's configuration
**Validates: Requirements 3.9**

### Property 15: Logout Token Clearing Timing
*For any* logout action, the Settings_Service SHALL clear all JWT tokens within 1 second
**Validates: Requirements 4.3**

### Property 16: Free Tier Premium Category Hiding
*For any* user with Free subscription, premium-only settings categories SHALL be hidden
**Validates: Requirements 4.5**

### Property 17: Premium Tier Category Display
*For any* user with Premium subscription, premium-specific settings categories SHALL be displayed
**Validates: Requirements 4.6, 5.1**

### Property 18: Free Tier Premium Features Hiding
*For any* user with Free subscription, the Premium Features category SHALL be hidden entirely
**Validates: Requirements 5.4**

### Property 19: Privacy Toggle Functionality
*For any* privacy setting toggle, all three toggles (analytics, crash reporting, usage statistics) SHALL be present
**Validates: Requirements 6.2**

### Property 20: Analytics Disabling
*For any* analytics disable action, telemetry data collection SHALL stop immediately
**Validates: Requirements 6.3**

### Property 21: Clear Data Confirmation
*For any* clear data action, a confirmation dialog SHALL be displayed before proceeding
**Validates: Requirements 6.5**

### Property 22: Desktop Settings Visibility
*For any* settings screen running on Windows or Linux platform, the Desktop settings category SHALL be displayed
**Validates: Requirements 7.1**

### Property 23: Window Behavior Options Presence
*For any* desktop settings, all window behavior options (Always on top, Remember position, Remember size) SHALL be present
**Validates: Requirements 7.2**

### Property 24: System Tray Options Presence
*For any* desktop settings, all system tray options (Minimize to tray, Close to tray, Show tray icon) SHALL be present
**Validates: Requirements 7.3**

### Property 25: Always On Top Timing
*For any* "Always on top" enable action, the Settings_Service SHALL apply the window property within 100 milliseconds
**Validates: Requirements 7.4**

### Property 26: Window Position Persistence Round Trip
*For any* window position and size settings, saving and restoring on next launch SHALL produce the same values
**Validates: Requirements 7.5**

### Property 27: Mobile Settings Category Visibility
*For any* settings screen running on mobile platform, the Mobile settings category SHALL be displayed
**Validates: Requirements 8.1**

### Property 28: Biometric Options Presence
*For any* mobile settings on supported devices, biometric authentication options SHALL be present
**Validates: Requirements 8.2**

### Property 29: Notification Preferences Presence
*For any* mobile settings, all notification preferences (Enable, Sound, Vibration) SHALL be present
**Validates: Requirements 8.3**

### Property 30: Biometric Registration Timing
*For any* biometric authentication enable action, the Settings_Service SHALL register the credential within 2 seconds
**Validates: Requirements 8.4**

### Property 31: Mobile Touch Target Size
*For any* mobile settings screen, all touch targets SHALL be at least 44x44 pixels
**Validates: Requirements 8.5**

### Property 32: Search Input Presence
*For any* settings screen, a search input field SHALL be displayed at the top
**Validates: Requirements 9.1**

### Property 33: Search Filtering Timing
*For any* search query, filtering and highlighting SHALL complete within 300 milliseconds
**Validates: Requirements 9.2**

### Property 34: Search Results Information
*For any* search result, the category name and setting description SHALL be displayed
**Validates: Requirements 9.3**

### Property 35: Search Result Navigation
*For any* search result click, the Settings_Screen SHALL navigate to and highlight the corresponding setting
**Validates: Requirements 9.4**

### Property 36: Keyboard Navigation Support
*For any* settings screen, keyboard navigation (Tab, Enter, Escape) SHALL be supported
**Validates: Requirements 9.5**

### Property 37: Validation Error Display Timing
*For any* invalid input, an inline error message SHALL be displayed within 200 milliseconds
**Validates: Requirements 10.1**

### Property 38: Save Prevention on Validation Errors
*For any* settings screen with validation errors, the save button SHALL be disabled
**Validates: Requirements 10.2**

### Property 39: Save Failure Error Handling
*For any* failed settings save operation, an error notification with retry option SHALL be displayed
**Validates: Requirements 10.3**

### Property 40: Required Field Validation on Navigation
*For any* navigation attempt with invalid required fields, navigation SHALL be blocked
**Validates: Requirements 10.4**

### Property 41: Success Confirmation Timing
*For any* successful validation, a success confirmation message SHALL be displayed for 2 seconds
**Validates: Requirements 10.5**

### Property 42: Export File Generation Timing
*For any* export action, a downloadable JSON file SHALL be created within 1 second
**Validates: Requirements 11.2**

### Property 43: Import File Validation
*For any* settings file import, the Validation_Engine SHALL validate format and content before applying
**Validates: Requirements 11.4**

### Property 44: Import Error Messages
*For any* invalid import file, specific error messages SHALL indicate which settings failed validation
**Validates: Requirements 11.5**

### Property 45: Settings Save Timing
*For any* settings modification, the change SHALL be saved to Preference_Store within 500 milliseconds
**Validates: Requirements 12.1**

### Property 46: Settings Load Timing
*For any* settings screen initialization, all saved preferences SHALL be loaded within 1 second
**Validates: Requirements 12.2**

### Property 47: Web Platform Storage
*For any* settings screen running on web platform, IndexedDB SHALL be used for persistent storage
**Validates: Requirements 12.3**

### Property 48: Windows Platform Storage
*For any* settings screen running on Windows platform, SQLite SHALL be used for persistent storage
**Validates: Requirements 12.4**

### Property 49: Mobile Platform Storage
*For any* settings screen running on mobile platform, SharedPreferences (Android) or UserDefaults (iOS) SHALL be used
**Validates: Requirements 12.5**

### Property 50: Storage Fallback
*For any* unavailable Preference_Store, in-memory storage SHALL be used and user SHALL be notified
**Validates: Requirements 12.6**

### Property 51: Mobile Layout Adaptation
*For any* screen width below 768 pixels, the Settings_Screen SHALL switch to single-column layout
**Validates: Requirements 13.1**

### Property 52: Web Accessibility
*For any* settings screen on web platform, proper ARIA labels and semantic HTML SHALL be present
**Validates: Requirements 13.2**

### Property 53: Desktop Keyboard Navigation
*For any* settings screen on desktop platform, keyboard-only navigation with visible focus indicators SHALL be supported
**Validates: Requirements 13.3**

### Property 54: Mobile Accessibility Labels
*For any* settings screen on mobile platform, proper accessibility labels for VoiceOver (iOS) and TalkBack (Android) SHALL be present
**Validates: Requirements 13.4**

### Property 55: Text Contrast Ratio
*For any* text element in the Settings_Screen, the contrast ratio SHALL be at least 4.5:1
**Validates: Requirements 13.5**

### Property 56: Responsive Reflow Timing
*For any* screen width change, content SHALL reflow within 300 milliseconds without data loss
**Validates: Requirements 13.6**

### Property 57: Admin Status Detection Timing
*For any* settings screen initialization, admin status check SHALL complete within 200 milliseconds
**Validates: Requirements 14.1**

### Property 58: Admin Button Visibility for Admins
*For any* authenticated admin user, the Admin Center button SHALL be displayed in Account settings
**Validates: Requirements 14.2**

### Property 59: Admin Button Hiding for Non-Admins
*For any* non-admin user, the Admin Center button SHALL be hidden
**Validates: Requirements 14.3**

### Property 60: Admin Center Navigation Timing
*For any* Admin Center button click, navigation to Admin Center URL SHALL complete within 500 milliseconds
**Validates: Requirements 14.4**

### Property 61: Session Token Passing
*For any* Admin Center navigation, the current session token SHALL be passed to maintain authentication
**Validates: Requirements 14.5**

### Property 62: Admin Button Keyboard Accessibility
*For any* Admin Center button, keyboard accessibility (Tab, Enter) and visible focus indicator SHALL be present
**Validates: Requirements 14.6**

### Property 63: Admin Button ARIA Label
*For any* Admin Center button, a descriptive ARIA label for screen readers SHALL be present
**Validates: Requirements 14.7**

### Property 64: Admin Center Error Handling
*For any* invalid or unreachable Admin Center URL, a user-friendly error message with retry option SHALL be displayed
**Validates: Requirements 14.8**

## Testing Strategy

### Unit Tests

- Category visibility logic (platform/role/subscription filtering)
- Search filtering logic
- Validation logic for each setting type
- Admin status detection
- Settings persistence and loading
- Provider configuration validation

### Widget Tests

- Settings screen renders correctly
- Category navigation works
- Search filters results
- Platform-specific UI renders
- Admin button appears for admin users
- Admin button hidden for non-admin users
- Responsive layout changes at breakpoints
- Accessibility features present

### Integration Tests

- Load settings from services
- Modify settings and save
- Verify settings persist
- Test provider configuration flow
- Test admin center navigation
- Test logout functionality
- Test import/export functionality
- Test cross-platform settings compatibility

### Property-Based Tests

- Each of the 64 correctness properties SHALL be tested with property-based testing
- Minimum 100 iterations per property test
- Use fast-check or similar PBT library for Dart/Flutter
- Generate random valid inputs and verify properties hold

## Performance Considerations

### Optimization

- Lazy load category content (only render active category)
- Debounce search (300ms)
- Debounce settings saves (500ms)
- Cache platform detection result
- Cache admin status check
- Cache subscription tier

### Memory

- Dispose listeners on screen close
- Limit search results display
- Stream-based model loading for large lists

## Accessibility

### WCAG 2.1 AA Compliance

- Semantic HTML (web)
- ARIA labels for all inputs
- Keyboard navigation (Tab, Enter, Escape)
- Screen reader support
- 4.5:1 contrast ratio minimum

### Platform-Specific

- **Web:** ARIA labels, semantic HTML
- **Windows:** Narrator support, keyboard shortcuts
- **Linux:** Screen reader support, keyboard shortcuts
- **iOS:** VoiceOver, dynamic type
- **Android:** TalkBack, high contrast mode

### Touch Targets

- Minimum 44x44 pixels on mobile
- Minimum 32x32 pixels on desktop
- Adequate spacing between elements

## Responsive Design

### Layout Breakpoints

- **Mobile (< 600px):** Single column, full-width inputs
- **Tablet (600-1024px):** Two columns, optimized spacing
- **Desktop (> 1024px):** Three columns, sidebar navigation

### Reflow Behavior

- Smooth transitions on orientation change
- No data loss during reflow
- Complete within 300ms

## Integration with Existing Services

### ProviderConfigurationManager

- Load configured providers on screen init
- Save new provider configurations
- Remove provider configurations
- Set preferred provider

### SettingsPreferenceService

- Load user preferences (theme, language)
- Save preference changes
- Extend with new preference types as needed

### AuthService

- Get current user email
- Check admin status
- Check subscription tier
- Handle logout
- Retrieve session token

### PlatformDetectionService

- Detect current platform
- Filter categories by platform
- Select platform-appropriate UI components

### NavigationService

- Navigate to Admin Center URL
- Pass session token for authentication
- Handle navigation errors

## Future Extensibility

### New Settings Categories

Add new categories by:
1. Creating category widget
2. Adding to category list
3. Implementing save/load logic
4. Adding to visibility filter if platform-specific

### New Provider Types

Support new LLM providers by:
1. Adding to provider type dropdown
2. Implementing provider-specific validation
3. Adding to LangChain integration

### Cloud Synchronization

Future enhancement:
- Sync settings across devices
- Conflict resolution
- Offline-first approach

### Admin Features

Future enhancements:
- User management dashboard
- System configuration
- Analytics and reporting
- Audit logging
