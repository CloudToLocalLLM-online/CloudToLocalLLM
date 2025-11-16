# Platform Settings Screen Design Document

## Overview

The Platform Settings Screen is a new, unified settings interface that consolidates user preferences and local LLM provider configuration into a single, platform-adaptive screen. This design focuses on implementing the missing pieces: a comprehensive settings UI that adapts to different platforms (web, Windows, mobile), integrates with existing services, and provides a cohesive user experience.

The screen will leverage existing services (`ProviderConfigurationManager`, `SettingsPreferenceService`, `PlatformDetectionService`, `AuthService`) while adding new UI components and orchestration logic to present settings in a user-friendly, platform-appropriate manner.

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
│   ├── PrivacySettingsCategory
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
[Load Existing Services]
    ├── ProviderConfigurationManager
    ├── SettingsPreferenceService
    ├── AuthService
    └── PlatformDetectionService
    ↓
[Filter Categories by Platform]
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
- Search functionality across all settings
- Category-based navigation
- Responsive layout (single column mobile, multi-column desktop)
- Admin access detection and navigation

**State Management:**
- Active category tracking
- Search query state
- Validation error state
- Loading state for async operations

**Integration Points:**
- `AuthService` - Get current user and admin status
- `PlatformDetectionService` - Detect platform
- `ProviderConfigurationManager` - Access provider configs
- `SettingsPreferenceService` - Access user preferences

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

**Responsibility:** Displays available settings categories based on platform and user role.

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

**Privacy Settings**
- Analytics toggle
- Crash reporting toggle
- Usage statistics toggle
- Clear data button

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

### 5. ProviderConfigurationUI

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

## Testing Strategy

### Unit Tests

- Category visibility logic (platform/role filtering)
- Search filtering logic
- Validation logic for each setting type
- Admin status detection

### Widget Tests

- Settings screen renders correctly
- Category navigation works
- Search filters results
- Platform-specific UI renders
- Admin button appears for admin users

### Integration Tests

- Load settings from services
- Modify settings and save
- Verify settings persist
- Test provider configuration flow
- Test admin center navigation

## Performance Considerations

### Optimization

- Lazy load category content (only render active category)
- Debounce search (300ms)
- Debounce settings saves (500ms)
- Cache platform detection result
- Cache admin status check

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
- Handle logout

### PlatformDetectionService

- Detect current platform
- Filter categories by platform
- Select platform-appropriate UI components

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

