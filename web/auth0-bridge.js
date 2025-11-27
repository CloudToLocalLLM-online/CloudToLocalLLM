// Auth0 Bridge for Flutter Web
// Provides a simple interface for Flutter to call Auth0 functions

const API_AUDIENCE = 'https://api.cloudtolocalllm.online';
const CALLBACK_STORAGE_KEY = 'auth0_callback_params';
const CALLBACK_FORWARDED_KEY = 'auth0_callback_forwarded';

function storeCallbackParams() {
  try {
    if (!window || !window.sessionStorage) return;
    const search = window.location.search || '';
    if (!search) return;
    if (
      search.includes('code=') ||
      search.includes('state=') ||
      search.includes('error=')
    ) {
      window.sessionStorage.setItem(CALLBACK_STORAGE_KEY, search);
      console.log(' Stored callback params in sessionStorage:', search);
      window.sessionStorage.removeItem(CALLBACK_FORWARDED_KEY);
    }
  } catch (err) {
    console.warn('Unable to store callback params in sessionStorage:', err);
  }
}

function clearStoredCallbackParams() {
  try {
    if (!window || !window.sessionStorage) return;
    window.sessionStorage.removeItem(CALLBACK_STORAGE_KEY);
    window.sessionStorage.removeItem(CALLBACK_FORWARDED_KEY);
    console.log(' Cleared callback params from sessionStorage');
  } catch (err) {
    console.warn('Unable to clear callback params in sessionStorage:', err);
  }
}

function getStoredCallbackSearch() {
  try {
    if (!window || !window.sessionStorage) return null;
    const stored = window.sessionStorage.getItem(CALLBACK_STORAGE_KEY);
    if (!stored || stored.length === 0) {
      return null;
    }
    return stored.startsWith('?') ? stored : `?${stored}`;
  } catch (err) {
    console.warn('Unable to read callback params from sessionStorage:', err);
    return null;
  }
}

storeCallbackParams();

window.auth0Bridge = {
  // Check if Auth0 client is initialized (synchronous check)
  isInitialized: function () {
    return window.auth0Client != null;
  },

  // Login with redirect (will show Auth0 Universal Login)
  loginWithRedirect: async function () {
    if (!window.auth0Client) {
      throw new Error('Auth0 client not initialized');
    }

    try {
      await window.auth0Client.loginWithRedirect({
        authorizationParams: {
          redirect_uri: window.location.origin,
          audience: API_AUDIENCE
        }
      });
    } catch (error) {
      console.error('Auth0 login error:', error);
      throw error;
    }
  },

  // Login with Google
  loginWithGoogle: async function () {
    if (!window.auth0Client) {
      const error = new Error('Auth0 client not initialized');
      console.error(' Auth0 login error:', error);
      throw error;
    }

    try {
      const audience = API_AUDIENCE;
      console.log(' Starting Auth0 Google login redirect with audience:', audience);
      await window.auth0Client.loginWithRedirect({
        authorizationParams: {
          connection: 'google-oauth2',
          redirect_uri: window.location.origin,
          audience: audience
        }
      });
      // Note: This will redirect, so code after this won't execute
    } catch (error) {
      console.error(' Auth0 Google login error:', error);
      // Don't throw - let the error propagate but log it
      throw error;
    }
  },

  // Check if this is a callback URL (has auth params)
  isCallbackUrl: function () {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.has('code') || urlParams.has('state') || urlParams.has('error');
  },

  // Handle redirect callback (call this after page load)
  handleRedirectCallback: async function () {
    if (!window.auth0Client) {
      return { success: false, error: 'Auth0 client not initialized' };
    }

    try {
      let searchToUse = window.location.search || '';
      const inlineParamsPresent =
        searchToUse.includes('code=') ||
        searchToUse.includes('state=') ||
        searchToUse.includes('error=');

      let usingStoredParams = false;
      if (!inlineParamsPresent) {
        const storedSearch = getStoredCallbackSearch();
        if (storedSearch) {
          searchToUse = storedSearch;
          usingStoredParams = true;
          console.log(' Using stored callback params for Auth0 redirect callback:', storedSearch);
        }
      }

      if (!searchToUse) {
        console.log(' No auth callback detected in URL or sessionStorage');
        return { success: false, error: 'No auth callback detected' };
      }

      const urlParams = new URLSearchParams(searchToUse);

      // Handle error callback
      if (urlParams.has('error')) {
        const error = urlParams.get('error');
        const errorDescription = urlParams.get('error_description') || 'Authentication failed';
        console.error(' Auth0 error in callback:', error, errorDescription);

        return {
          success: false,
          error: errorDescription,
          errorCode: error
        };
      }

      // Handle success callback
      if (urlParams.has('code') || urlParams.has('state')) {
        console.log(' Processing Auth0 callback...');
        const baseUrl = window.location.origin + window.location.pathname;
        const hash = window.location.hash || '';
        const callbackUrl = usingStoredParams
          ? `${baseUrl}${searchToUse}${hash}`
          : window.location.href;

        const result = await window.auth0Client.handleRedirectCallback(callbackUrl);
        console.log(' Auth0 callback processed successfully');

        // Clean up URL and stored params only after success
        window.history.replaceState({}, document.title, window.location.pathname);
        clearStoredCallbackParams();

        return {
          success: true,
          appState: result.appState
        };
      }

      console.log(' No auth callback detected in URL parameters');
      return { success: false, error: 'No auth callback detected' };
    } catch (error) {
      console.error('Auth0 redirect callback error:', error);
      return {
        success: false,
        error: error.message || error.toString()
      };
    }
  },

  // Check if user is authenticated
  isAuthenticated: async function () {
    if (!window.auth0Client) {
      return false;
    }

    try {
      return await window.auth0Client.isAuthenticated();
    } catch (error) {
      console.error('Auth0 isAuthenticated error:', error);
      return false;
    }
  },

  // Get user info
  getUser: async function () {
    if (!window.auth0Client) {
      return null;
    }

    try {
      const isAuth = await window.auth0Client.isAuthenticated();
      if (!isAuth) {
        return null;
      }

      const user = await window.auth0Client.getUser();
      return user ? JSON.stringify(user) : null;
    } catch (error) {
      console.error('Auth0 getUser error:', error);
      return null;
    }
  },

  // Get access token
  getAccessToken: async function () {
    if (!window.auth0Client) {
      return null;
    }

    try {
      const isAuth = await window.auth0Client.isAuthenticated();
      if (!isAuth) {
        return null;
      }

      const audience = API_AUDIENCE;
      return await window.auth0Client.getTokenSilently({
        authorizationParams: {
          audience: API_AUDIENCE,
          scope: 'openid profile email offline_access'
        }
      });
    } catch (error) {
      console.error('Auth0 getAccessToken error:', error);
      // Do NOT automatically redirect here. Let the app handle the failure.
      // If we redirect here, it causes an infinite loop if silent auth fails.
      return null;
    }
  },

  // Logout
  logout: async function () {
    if (!window.auth0Client) {
      throw new Error('Auth0 client not initialized');
    }

    try {
      await window.auth0Client.logout({
        logoutParams: {
          returnTo: window.location.origin
        }
      });
    } catch (error) {
      console.error('Auth0 logout error:', error);
      throw error;
    }
  }
};

console.log(' Auth0 Bridge initialized');

