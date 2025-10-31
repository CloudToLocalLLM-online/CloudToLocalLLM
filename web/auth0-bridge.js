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
          redirect_uri: window.location.origin
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
      throw new Error('Auth0 client not initialized');
    }
    
    try {
      await window.auth0Client.loginWithRedirect({
        authorizationParams: {
          connection: 'google-oauth2',
          redirect_uri: window.location.origin
        }
      });
    } catch (error) {
      console.error('Auth0 Google login error:', error);
      throw error;
    }
  },

  // Handle redirect callback (call this after page load)
  handleRedirectCallback: async function() {
    if (!window.auth0Client) {
      return { success: false, error: 'Auth0 client not initialized' };
    }

    try {
      // Check if we're returning from Auth0
      if (window.location.search.includes('code=') || 
          window.location.search.includes('state=') ||
          window.location.search.includes('error=')) {
        
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
        error: error.message
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
      
      return await window.auth0Client.getUser();
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
      
      return await window.auth0Client.getTokenSilently();
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

console.log('✅ Auth0 Bridge initialized');

