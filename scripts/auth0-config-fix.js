#!/usr/bin/env node

/**
 * Auth0 Configuration Fix Script
 * Updates Auth0 application settings to fix CORS and session persistence issues
 */

import { ManagementClient } from 'auth0';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Auth0 Management API configuration
const auth0Management = new ManagementClient({
  domain: process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com',
  clientId: process.env.AUTH0_M2M_CLIENT_ID, // Machine-to-Machine client ID
  clientSecret: process.env.AUTH0_M2M_CLIENT_SECRET, // Machine-to-Machine client secret
  scope: 'read:clients update:clients'
});

// Application configuration
const CLIENT_ID = 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A';
const PRODUCTION_DOMAIN = 'https://app.cloudtolocalllm.online';
const DEVELOPMENT_DOMAINS = [
  'http://localhost:3000',
  'http://localhost:4200',
  'http://localhost:5000',
  'http://localhost:8080'
];

async function updateAuth0Configuration() {
  try {
    console.log('🔧 Starting Auth0 configuration update...');
    
    // Get current client configuration
    console.log('📋 Fetching current client configuration...');
    const currentClient = await auth0Management.clients.get({ client_id: CLIENT_ID });
    
    console.log('Current configuration:');
    console.log('- Allowed Callback URLs:', currentClient.callbacks);
    console.log('- Allowed Web Origins:', currentClient.web_origins);
    console.log('- Allowed Origins (CORS):', currentClient.allowed_origins);
    console.log('- Allowed Logout URLs:', currentClient.allowed_logout_urls);
    
    // Define the updated configuration
    const updatedConfig = {
      // Callback URLs - where Auth0 redirects after authentication
      callbacks: [
        `${PRODUCTION_DOMAIN}/callback`,
        ...DEVELOPMENT_DOMAINS.map(domain => `${domain}/callback`)
      ],
      
      // Web Origins - for silent authentication and token refresh
      web_origins: [
        PRODUCTION_DOMAIN,
        ...DEVELOPMENT_DOMAINS
      ],
      
      // Allowed Origins (CORS) - for cross-origin requests
      allowed_origins: [
        PRODUCTION_DOMAIN,
        ...DEVELOPMENT_DOMAINS
      ],
      
      // Logout URLs - where Auth0 redirects after logout
      allowed_logout_urls: [
        PRODUCTION_DOMAIN,
        ...DEVELOPMENT_DOMAINS
      ],
      
      // JWT Configuration for better session management
      jwt_configuration: {
        lifetime_in_seconds: 36000, // 10 hours
        secret_encoded: false,
        alg: 'RS256'
      },
      
      // Token endpoint authentication method
      token_endpoint_auth_method: 'none', // For SPA
      
      // Application type
      app_type: 'spa',
      
      // Grant types
      grant_types: [
        'authorization_code',
        'implicit',
        'refresh_token'
      ],
      
      // Response types
      response_types: [
        'code',
        'id_token',
        'token'
      ],
      
      // OIDC conformant
      oidc_conformant: true,
      
      // Refresh token settings for session persistence
      refresh_token: {
        rotation_type: 'rotating',
        expiration_type: 'expiring',
        leeway: 0,
        token_lifetime: 2592000, // 30 days
        infinite_token_lifetime: false,
        infinite_idle_token_lifetime: false,
        idle_token_lifetime: 1296000 // 15 days
      }
    };
    
    console.log('\n🔄 Updating Auth0 client configuration...');
    
    // Update the client configuration
    const updatedClient = await auth0Management.clients.update(
      { client_id: CLIENT_ID },
      updatedConfig
    );
    
    console.log('\n✅ Auth0 configuration updated successfully!');
    console.log('\nUpdated configuration:');
    console.log('- Allowed Callback URLs:', updatedClient.callbacks);
    console.log('- Allowed Web Origins:', updatedClient.web_origins);
    console.log('- Allowed Origins (CORS):', updatedClient.allowed_origins);
    console.log('- Allowed Logout URLs:', updatedClient.allowed_logout_urls);
    console.log('- JWT Lifetime:', updatedClient.jwt_configuration?.lifetime_in_seconds, 'seconds');
    console.log('- Refresh Token Lifetime:', updatedClient.refresh_token?.token_lifetime, 'seconds');
    
    console.log('\n🎯 CORS and session persistence issues should now be resolved!');
    console.log('🔄 Please test the application at:', PRODUCTION_DOMAIN);
    
  } catch (error) {
    console.error('❌ Error updating Auth0 configuration:', error.message);
    
    if (error.statusCode === 401) {
      console.error('🔑 Authentication failed. Please check your M2M credentials.');
      console.error('Required environment variables:');
      console.error('- AUTH0_M2M_CLIENT_ID');
      console.error('- AUTH0_M2M_CLIENT_SECRET');
    } else if (error.statusCode === 403) {
      console.error('🚫 Insufficient permissions. Ensure your M2M application has:');
      console.error('- read:clients');
      console.error('- update:clients');
    }
    
    process.exit(1);
  }
}

// Run the configuration update
updateAuth0Configuration();
