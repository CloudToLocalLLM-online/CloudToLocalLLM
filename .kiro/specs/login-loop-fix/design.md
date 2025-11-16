# Design Document: Login Loop Fix

## Overview

This design addresses the authentication login loop issue where users experience infinite redirects between `/login` and `/callback` routes. The root cause is a race condition between authentication state updates and router redirect logic, combined with improper handling of callback parameters and Auth0 client initialization timing.

The solution implements a robust authentication flow with PostgreSQL-backed session persistence, proper state synchronization, and enhanced logging to prevent redirect loops.

## Architecture

### High-Level Flow

```
User clicks login
    ↓
Auth0 redirect (external)
    ↓
Return with callback params (code, state)
    ↓
Router detects params → redirect to /callback
    ↓
CallbackScreen processes callback
    ↓
Auth0WebService exchanges code for tokens
    ↓
AuthService immediately saves to PostgreSQL
    ↓
AuthService sets isAuthenticated = true
    ↓
Router redirects to home (no loop)
```

### Key Components

1. **Router (lib/config/router.dart)**
   - Detects callback parameters in URL
   - Manages redirect logic with loop prevention
   - Checks authentication state before redirecting

2. **CallbackScreen (lib/screens/callback_screen.dart)**
   - Processes Auth0 callback
   - Waits for state synchronization
   - Handles errors gracefully

3. **Auth0WebService (lib/services/auth0_web_service.dart)**
   - Exchanges authorization code for tokens
   - Ensures Auth0 client is initialized
   - Returns success/failure status

4. **AuthService (lib/services/auth_service.dart)**
   - Orchestrates authentication flow
   - Immediately persists tokens to PostgreSQL
   - Updates authentication state after persistence
   - Loads authenticated services

5. **SessionStorageService (lib/services/session_storage_service.dart)**
   - Persists sessions to PostgreSQL
   - Validates existing sessions
   - Manages session lifecycle

## Components and Interfaces

### Router Redirect Logic

**Current Issues:**
- Callback parameters processed multiple times
- No tracking of forwarded callback parameters
- Race condition between auth state check and redirect

**Design Changes:**

```dart
// Add callback forwarding tracking
const _callbackForwardedKey = 'auth0_callback_forwarded';

// In redirect function:
1. Check if callback params exist in URL
2. Check if params already forwarded (sessionStorage flag)
3. If params exist AND not forwarded:
   - Set forwarded flag in sessionStorage
   - Redirect to /callback with params
   - Return immediately
4. If on /callback route:
   - Allow processing
   - Clear forwarded flag after processing
5. Never redirect from /callback to /login if params present
```

### CallbackScreen Processing

**Current Issues:**
- 300ms delay is arbitrary and may be insufficient
- No verification that auth state actually changed
- No retry logic for Auth0 client initialization

**Design Changes:**

```dart
Future<void> _processCallback() async {
  // 1. Verify Auth0 client is ready
  await _ensureAuth0ClientReady();
  
  // 2. Process callback
  final success = await authService.handleCallback();
  
  if (success) {
    // 3. Wait for PostgreSQL session creation
    await _waitForSessionPersistence();
    
    // 4. Verify auth state is true
    if (authService.isAuthenticated.value) {
      // 5. Clear callback forwarded flag
      _clearCallbackForwardedFlag();
      
      // 6. Navigate to home
      context.pushReplacement('/');
    } else {
      // Auth state not set - log error and retry
      await _retryAuthStateCheck();
    }
  } else {
    // Callback failed - redirect to login
    context.go('/login');
  }
}
```

### Auth0WebService Token Exchange

**Current Issues:**
- Client readiness check may timeout too quickly
- No distinction between "not ready" and "failed"
- Callback handling doesn't verify token retrieval

**Design Changes:**

```dart
@override
Future<bool> handleRedirectCallback() async {
  try {
    // 1. Ensure client is ready with extended timeout for callback
    await _ensureClientReadyForCallback();
    
    // 2. Call Auth0 SDK handleRedirectCallback
    final result = await auth0Bridge!.handleRedirectCallback();
    
    // 3. Verify we got tokens
    final success = result['success'] == true;
    
    if (success) {
      // 4. Immediately check auth status to populate tokens
      await checkAuthStatus();
      
      // 5. Verify tokens are available
      if (_accessToken != null && _currentUser != null) {
        return true;
      } else {
        debugPrint('Callback succeeded but tokens not available');
        return false;
      }
    }
    
    return false;
  } catch (e) {
    debugPrint('Callback processing error: $e');
    return false;
  }
}
```

### AuthService Session Persistence

**Current Issues:**
- Session storage happens asynchronously without waiting
- Auth state set before PostgreSQL persistence completes
- No verification that session was created

**Design Changes:**

```dart
Future<void> _handleSuccessfulCallback() async {
  // 1. Get tokens from Auth0Service
  final accessToken = _auth0Service.getAccessToken();
  final user = UserModel.fromAuth0Profile(_auth0Service.currentUser!);
  
  // 2. Immediately persist to PostgreSQL (BLOCKING)
  try {
    final session = await _sessionStorage.createSession(
      user: user,
      auth0AccessToken: accessToken,
      auth0IdToken: null,
    );
    
    // 3. Store session token locally
    _sessionToken = session.token;
    _currentUser = user;
    
    // 4. Only NOW set auth state to true
    _isAuthenticated.value = true;
    notifyListeners();
    
    // 5. Load authenticated services (async, non-blocking)
    _loadAuthenticatedServices();
    
  } catch (e) {
    debugPrint('Failed to persist session: $e');
    // Don't set auth state if persistence failed
    throw Exception('Session persistence failed');
  }
}
```

## Data Models

### Session Flow State

```dart
enum CallbackProcessingState {
  initial,
  checkingClient,
  exchangingTokens,
  persistingSession,
  updatingAuthState,
  complete,
  failed,
}
```

### Callback Parameters Tracking

```dart
class CallbackParams {
  final String code;
  final String state;
  final bool forwarded;
  final DateTime timestamp;
  
  bool get isExpired => 
    DateTime.now().difference(timestamp) > Duration(minutes: 5);
}
```

## Error Handling

### Auth0 Client Not Ready

```
Error: Auth0 client not initialized
Action: 
  1. Show loading screen with "Initializing authentication..."
  2. Retry initialization up to 3 times with exponential backoff
  3. If all retries fail, show error and redirect to login
```

### Token Exchange Failed

```
Error: handleRedirectCallback returned false
Action:
  1. Log detailed error from Auth0 SDK
  2. Check if error is "invalid_grant" (expired code)
  3. Clear callback params and redirect to login
  4. Show user-friendly error message
```

### PostgreSQL Session Creation Failed

```
Error: SessionStorageService.createSession throws exception
Action:
  1. Log error details
  2. DO NOT set isAuthenticated = true
  3. Clear Auth0 state
  4. Redirect to login with error message
  5. User must retry authentication
```

### Infinite Redirect Detected

```
Detection: Same route visited >3 times in 10 seconds
Action:
  1. Break redirect cycle immediately
  2. Clear all callback params and flags
  3. Clear authentication state
  4. Redirect to login with error message
  5. Log detailed redirect history for debugging
```

## Testing Strategy

### Unit Tests

1. **Router Redirect Logic**
   - Test callback param detection
   - Test forwarded flag prevents re-processing
   - Test auth state prevents login redirect
   - Test callback route allows processing

2. **CallbackScreen Processing**
   - Test successful callback flow
   - Test failed callback handling
   - Test Auth0 client not ready scenario
   - Test session persistence failure

3. **Auth0WebService**
   - Test client readiness checks
   - Test token exchange success/failure
   - Test checkAuthStatus after callback

4. **AuthService Session Persistence**
   - Test session created before auth state set
   - Test session creation failure prevents auth
   - Test authenticated services load after auth

### Integration Tests

1. **End-to-End Authentication Flow**
   - User clicks login → Auth0 redirect → callback → home
   - Verify no redirects to login after successful auth
   - Verify PostgreSQL session created
   - Verify authenticated services loaded

2. **Error Recovery**
   - Simulate Auth0 client initialization failure
   - Simulate token exchange failure
   - Simulate PostgreSQL connection failure
   - Verify graceful error handling and user feedback

3. **Race Condition Prevention**
   - Simulate slow network during callback
   - Verify auth state not set before session persisted
   - Verify router waits for auth state before redirect

### Manual Testing

1. **Login Loop Detection**
   - Monitor browser console for redirect logs
   - Verify no more than 2 redirects during auth flow
   - Verify callback params processed exactly once

2. **Session Persistence**
   - Verify PostgreSQL session created immediately after callback
   - Verify session token stored in SharedPreferences
   - Verify session survives page refresh

3. **Performance**
   - Measure time from callback to home screen
   - Target: < 2 seconds for full flow
   - Verify no unnecessary delays

## Implementation Notes

### Logging Strategy

All components must log:
- Entry/exit of critical functions
- Authentication state changes
- Redirect decisions with reasons
- Error conditions with stack traces
- Timing information for performance analysis

Log format:
```
[ComponentName] Action: details
```

Example:
```
[Router] Redirect check: /callback
[Router] hasCallbackParams: true, isAuthenticated: false
[Router] Decision: Allow callback processing
```

### Backward Compatibility

- Existing PostgreSQL sessions remain valid
- No database schema changes required
- Desktop authentication flow unchanged
- Only web authentication flow modified

### Performance Considerations

- Session persistence adds ~100-200ms to auth flow
- Acceptable tradeoff for reliability
- Authenticated services load asynchronously to avoid blocking
- Router checks are synchronous and fast (<1ms)

### Security Considerations

- Callback parameters contain sensitive authorization codes
- Clear callback params from URL after processing
- Session tokens stored securely in SharedPreferences
- PostgreSQL sessions have 24-hour expiration
- No sensitive data logged in production builds
