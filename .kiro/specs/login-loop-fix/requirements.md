# Requirements Document

## Introduction

This document specifies the requirements for debugging and fixing the authentication login loop issue in CloudToLocalLLM. The system currently experiences infinite redirect cycles between `/login` and `/callback` routes during the Auth0 authentication flow on the web platform. This issue prevents users from successfully authenticating and accessing the application.

## Glossary

- **Auth0Service**: The authentication service interface that handles Auth0 integration
- **Auth0WebService**: Web platform implementation of Auth0Service using JavaScript interop
- **AuthService**: Main authentication service that wraps Auth0Service and manages session state
- **CallbackScreen**: Flutter screen that processes Auth0 redirect callbacks
- **LoginScreen**: Flutter screen that initiates the Auth0 login flow
- **Router**: GoRouter-based navigation system that handles route redirects
- **SessionStorage**: Browser sessionStorage API used to persist callback parameters temporarily during redirect
- **SessionStorageService**: PostgreSQL-backed service that persists authentication sessions and tokens
- **PostgreSQL Session**: Database record containing user authentication data, tokens, and session metadata
- **Auth0Bridge**: JavaScript bridge that interfaces with Auth0 SDK
- **Callback Parameters**: URL query parameters (code, state) returned by Auth0 after authentication

## Requirements

### Requirement 1

**User Story:** As a user attempting to log in, I want the authentication flow to complete successfully without infinite redirects, so that I can access the application.

#### Acceptance Criteria

1. WHEN THE User clicks the login button, THE Auth0Service SHALL initiate the Auth0 login redirect
2. WHEN Auth0 returns callback parameters, THE Router SHALL detect the callback parameters and redirect to the callback route
3. WHEN THE CallbackScreen processes the callback, THE Auth0WebService SHALL exchange the authorization code for tokens
4. WHEN token exchange completes successfully, THE AuthService SHALL immediately persist the tokens and user data to PostgreSQL via SessionStorageService
5. WHEN THE PostgreSQL session is created, THE AuthService SHALL update the authentication state to authenticated
6. WHEN authentication state becomes true, THE Router SHALL redirect the user to the home route without returning to login

### Requirement 2

**User Story:** As a developer debugging authentication issues, I want comprehensive logging throughout the authentication flow, so that I can identify where the loop occurs.

#### Acceptance Criteria

1. THE Auth0WebService SHALL log each step of the callback handling process including client readiness checks
2. THE CallbackScreen SHALL log authentication state before and after callback processing
3. THE Router SHALL log all redirect decisions including query parameters and authentication state
4. THE AuthService SHALL log authentication state changes and service loading status
5. WHEN a redirect occurs, THE Router SHALL log the source route, destination route, and reason for redirect

### Requirement 3

**User Story:** As a user with a slow network connection, I want the authentication flow to wait for Auth0 client initialization, so that callback processing does not fail due to timing issues.

#### Acceptance Criteria

1. WHEN THE CallbackScreen processes a callback, THE Auth0WebService SHALL verify the Auth0 client is initialized before processing
2. IF THE Auth0 client is not initialized, THEN THE Auth0WebService SHALL wait up to 5 seconds for initialization
3. WHEN THE Auth0 client initialization times out, THE Auth0WebService SHALL return a failure result
4. THE CallbackScreen SHALL display appropriate error messages when callback processing fails
5. WHEN callback processing fails, THE Router SHALL redirect the user to the login screen

### Requirement 4

**User Story:** As a user completing authentication, I want the system to prevent race conditions between authentication state updates and navigation, so that I am not redirected back to login after successful authentication.

#### Acceptance Criteria

1. WHEN THE CallbackScreen completes callback processing successfully, THE AuthService SHALL persist the session to PostgreSQL before setting authentication state
2. WHEN THE PostgreSQL session is successfully created, THE AuthService SHALL set the authentication state to true before any navigation occurs
3. THE CallbackScreen SHALL wait for authentication state propagation before triggering navigation
4. WHEN THE Router checks authentication state during redirect, THE Router SHALL use the current authentication state value
5. THE Router SHALL NOT redirect authenticated users to the login screen
6. WHEN authenticated services are loading, THE Router SHALL display a loading screen instead of redirecting to login

### Requirement 5

**User Story:** As a system administrator, I want all authentication data stored exclusively in PostgreSQL, so that authentication state persists across browser sessions and can be managed centrally.

#### Acceptance Criteria

1. WHEN THE Auth0WebService receives tokens from Auth0, THE AuthService SHALL immediately call SessionStorageService to create a PostgreSQL session
2. THE SessionStorageService SHALL store the access token, user profile, and session metadata in PostgreSQL
3. THE AuthService SHALL NOT rely on browser localStorage or sessionStorage for authentication state persistence
4. WHEN THE application initializes, THE AuthService SHALL check PostgreSQL for existing valid sessions before checking Auth0 state
5. WHEN a valid PostgreSQL session exists, THE AuthService SHALL set authentication state to true without requiring Auth0 re-authentication

### Requirement 6

**User Story:** As a developer, I want to identify and eliminate circular redirect logic in the router, so that users cannot get stuck in redirect loops.

#### Acceptance Criteria

1. THE Router SHALL NOT redirect from callback route to login route when callback parameters are present
2. THE Router SHALL NOT redirect from home route to login route when authentication state is true
3. WHEN THE Router detects callback parameters on a non-callback route, THE Router SHALL redirect to callback route exactly once
4. THE Router SHALL mark callback parameters as processed after forwarding to callback route
5. THE Router SHALL NOT process already-forwarded callback parameters again
