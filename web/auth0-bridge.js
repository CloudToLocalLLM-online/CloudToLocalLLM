// Auth0 JavaScript Bridge for Flutter Web
// Handles Auth0 authentication flow for web platform

(function () {
  'use strict';

  // Configuration - should match Flutter Auth0AuthProvider
  const AUTH0_DOMAIN = 'dev-v2f2p008x3dr74ww.us.auth0.com';
  const AUTH0_CLIENT_ID = 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A';
  const AUTH0_AUDIENCE = 'https://dev-v2f2p008x3dr74ww.us.auth0.com/api/v2/';

  // Auth0 SDK instance
  let auth0 = null;

  // Initialize Auth0
  function initializeAuth0() {
    if (auth0) return auth0;

    // Load Auth0 SPA SDK if not already loaded
    if (!window.auth0) {
      console.warn('[Auth0 Bridge] Auth0 SDK not loaded. Make sure to include the Auth0 SPA SDK script.');
      return null;
    }

    try {
      // Auth0 SPA JS v2 uses Auth0Client class
      // options structure changed in v2: client_id -> clientId, and params moved to authorizationParams
      auth0 = new window.auth0.Auth0Client({
        domain: AUTH0_DOMAIN,
        clientId: AUTH0_CLIENT_ID,
        authorizationParams: {
          audience: AUTH0_AUDIENCE,
          redirect_uri: window.location.origin,
          scope: 'openid profile email offline_access',
        },
        cacheLocation: 'localstorage',
        useRefreshTokens: true,
      });

      console.log('[Auth0 Bridge] Auth0 initialized successfully');
      return auth0;
    } catch (error) {
      console.error('[Auth0 Bridge] Failed to initialize Auth0:', error);
      return null;
    }
  }

  // Login function
  window.auth0BridgeLogin = async function () {
    try {
      console.log('[Auth0 Bridge] Starting login process...');

      const client = initializeAuth0();
      if (!client) {
        throw new Error('Auth0 client not initialized');
      }

      // Check if we have a valid session first
      try {
        const user = await client.getUser();
        const token = await client.getTokenSilently();
        if (user && token) {
          console.log('[Auth0 Bridge] Found existing valid session');
          // Notify Flutter that we're already authenticated
          if (window.flutterAuthCallback) {
            window.flutterAuthCallback({
              type: 'success',
              user: user,
              accessToken: token,
            });
          }
          return;
        }
      } catch (e) {
        console.log('[Auth0 Bridge] No valid existing session, proceeding with login');
      }

      // Start the login flow
      await client.loginWithRedirect({
        authorizationParams: {
          redirect_uri: window.location.origin,
        },
        appState: {
          returnTo: window.location.pathname,
        },
      });

    } catch (error) {
      console.error('[Auth0 Bridge] Login failed:', error);

      // Notify Flutter of the error
      if (window.flutterAuthCallback) {
        window.flutterAuthCallback({
          type: 'error',
          error: error.message || 'Login failed',
          code: error.error || 'unknown_error',
        });
      }
    }
  };

  // Handle redirect callback
  window.auth0BridgeHandleRedirect = async function () {
    try {
      console.log('[Auth0 Bridge] Handling redirect callback...');

      const client = initializeAuth0();
      if (!client) {
        throw new Error('Auth0 client not initialized');
      }

      // Handle the redirect callback
      const result = await client.handleRedirectCallback();

      // Get user and token
      const user = await client.getUser();
      const token = await client.getTokenSilently();

      console.log('[Auth0 Bridge] Redirect handled successfully');

      // Notify Flutter of success
      if (window.flutterAuthCallback) {
        window.flutterAuthCallback({
          type: 'success',
          user: user,
          accessToken: token,
          appState: result.appState,
        });
      }

      // Redirect back to the app
      const returnTo = result.appState?.returnTo || '/';
      window.history.replaceState({}, document.title, returnTo);

    } catch (error) {
      console.error('[Auth0 Bridge] Redirect handling failed:', error);

      // Notify Flutter of the error
      if (window.flutterAuthCallback) {
        window.flutterAuthCallback({
          type: 'error',
          error: error.message || 'Redirect handling failed',
          code: error.error || 'redirect_error',
        });
      }
    }
  };

  // Logout function
  window.auth0BridgeLogout = async function () {
    try {
      console.log('[Auth0 Bridge] Starting logout process...');

      const client = initializeAuth0();
      if (!client) {
        throw new Error('Auth0 client not initialized');
      }

      await client.logout({
        logoutParams: {
          returnTo: window.location.origin,
        },
      });

      console.log('[Auth0 Bridge] Logout completed');

      // Notify Flutter of logout
      if (window.flutterAuthCallback) {
        window.flutterAuthCallback({
          type: 'logout',
        });
      }

    } catch (error) {
      console.error('[Auth0 Bridge] Logout failed:', error);

      // Notify Flutter of the error (but logout is usually successful)
      if (window.flutterAuthCallback) {
        window.flutterAuthCallback({
          type: 'error',
          error: error.message || 'Logout failed',
          code: error.error || 'logout_error',
        });
      }
    }
  };

  // Get current user
  window.auth0BridgeGetUser = async function () {
    try {
      const client = initializeAuth0();
      if (!client) return null;

      return await client.getUser();
    } catch (error) {
      console.error('[Auth0 Bridge] Failed to get user:', error);
      return null;
    }
  };

  // Get access token
  window.auth0BridgeGetToken = async function () {
    try {
      const client = initializeAuth0();
      if (!client) return null;

      return await client.getTokenSilently();
    } catch (error) {
      console.error('[Auth0 Bridge] Failed to get token:', error);
      return null;
    }
  };

  // Check if user is authenticated
  window.auth0BridgeIsAuthenticated = async function () {
    try {
      const client = initializeAuth0();
      if (!client) return false;

      const user = await client.getUser();
      return !!user;
    } catch (error) {
      console.log('[Auth0 Bridge] User not authenticated:', error.message);
      return false;
    }
  };

  // Initialize on page load
  document.addEventListener('DOMContentLoaded', function () {
    console.log('[Auth0 Bridge] Bridge loaded and ready');

    // Check if this is a redirect callback
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('code') && urlParams.has('state')) {
      console.log('[Auth0 Bridge] Detected redirect callback, handling...');
      window.auth0BridgeHandleRedirect();
    }
  });

  // Expose bridge functions globally
  window.Auth0Bridge = {
    login: window.auth0BridgeLogin,
    logout: window.auth0BridgeLogout,
    getUser: window.auth0BridgeGetUser,
    getToken: window.auth0BridgeGetToken,
    isAuthenticated: window.auth0BridgeIsAuthenticated,
    handleRedirect: window.auth0BridgeHandleRedirect,
  };

})();