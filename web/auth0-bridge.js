// Auth0 Bridge for Flutter Web
// Provides a simple interface for Flutter to call Auth0 functions

window.auth0Bridge = {
  // Check if Auth0 client is initialized
  isInitialized: function() {
    return window.auth0Client != null;
  },

  // Login with redirect (will show Auth0 Universal Login)
  loginWithRedirect: async function() {
    if (!window.auth0Client) {
      throw new Error('Auth0 client not initialized');
    }
    
    try {
      await window.auth0Client.loginWithRedirect({
        authorizationParams: {
          redirect_uri: window.location.origin,
          audience: 'https://app.cloudtolocalllm.online'
        }
      });
    } catch (error) {
      console.error('Auth0 login error:', error);
      throw error;
    }
  },

  // Login with Google
  loginWithGoogle: async function() {
    if (!window.auth0Client) {
      const error = new Error('Auth0 client not initialized');
      console.error(' Auth0 login error:', error);
      throw error;
    }
    
    try {
      const audience = 'https://app.cloudtolocalllm.online';
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

  // Handle redirect callback (call this after page load)
  handleRedirectCallback: async function() {
    if (!window.auth0Client) {
      return { success: false, error: 'Auth0 client not initialized' };
    }

    try {
      // Check URL parameters
      const urlParams = new URLSearchParams(window.location.search);
      
      // Handle error callback
      if (urlParams.has('error')) {
        const error = urlParams.get('error');
        const errorDescription = urlParams.get('error_description') || 'Authentication failed';
        console.error(' Auth0 error in callback:', error, errorDescription);
        
        // Clean up URL
        window.history.replaceState({}, document.title, window.location.pathname);
        
        return {
          success: false,
          error: errorDescription,
          errorCode: error
        };
      }
      
      // Handle success callback
      if (urlParams.has('code') || urlParams.has('state')) {
        const result = await window.auth0Client.handleRedirectCallback();
        
        // Clean up URL
        window.history.replaceState({}, document.title, window.location.pathname);
        
        return {
          success: true,
          appState: result.appState
        };
      }
      
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
  isAuthenticated: async function() {
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
  getUser: async function() {
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
  getAccessToken: async function() {
    if (!window.auth0Client) {
      return null;
    }
    
    try {
      const isAuth = await window.auth0Client.isAuthenticated();
      if (!isAuth) {
        return null;
      }
      
      const audience = 'https://app.cloudtolocalllm.online';
      return await window.auth0Client.getTokenSilently({
        authorizationParams: {
          audience: audience,
          scope: 'openid profile email offline_access'
        }
      });
    } catch (error) {
      console.error('Auth0 getAccessToken error:', error);
      // If getting token silently fails, try to re-authenticate
      if (error.error === 'login_required') {
        await window.auth0Bridge.loginWithRedirect();
      }
      return null;
    }
  },

  // Logout
  logout: async function() {
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

