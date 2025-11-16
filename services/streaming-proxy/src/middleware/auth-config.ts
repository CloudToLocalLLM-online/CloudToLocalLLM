/**
 * Authentication Configuration
 * Centralized configuration for authentication middleware
 */

export interface AuthConfig {
  auth0: {
    domain: string;
    audience: string;
    issuer: string;
  };
  cache: {
    validationDuration: number; // milliseconds
    jwksDuration: number; // milliseconds
  };
  bruteForce: {
    threshold: number; // failed attempts
    window: number; // milliseconds
    blockDuration: number; // milliseconds
  };
  audit: {
    maxHistorySize: number;
    retentionDays: number;
  };
}

/**
 * Load authentication configuration from environment variables
 */
export function loadAuthConfig(): AuthConfig {
  const auth0Domain = process.env.AUTH0_DOMAIN;
  const auth0Audience = process.env.AUTH0_AUDIENCE;

  if (!auth0Domain || !auth0Audience) {
    throw new Error('AUTH0_DOMAIN and AUTH0_AUDIENCE environment variables are required');
  }

  return {
    auth0: {
      domain: auth0Domain,
      audience: auth0Audience,
      issuer: process.env.AUTH0_ISSUER || `https://${auth0Domain}/`,
    },
    cache: {
      validationDuration: parseInt(process.env.AUTH_CACHE_DURATION || '300000'), // 5 minutes
      jwksDuration: parseInt(process.env.JWKS_CACHE_DURATION || '3600000'), // 1 hour
    },
    bruteForce: {
      threshold: parseInt(process.env.BRUTE_FORCE_THRESHOLD || '5'),
      window: parseInt(process.env.BRUTE_FORCE_WINDOW || '300000'), // 5 minutes
      blockDuration: parseInt(process.env.BRUTE_FORCE_BLOCK_DURATION || '3600000'), // 1 hour
    },
    audit: {
      maxHistorySize: parseInt(process.env.AUDIT_MAX_HISTORY || '10000'),
      retentionDays: parseInt(process.env.AUDIT_RETENTION_DAYS || '90'),
    },
  };
}

/**
 * Validate authentication configuration
 */
export function validateAuthConfig(config: AuthConfig): void {
  if (!config.auth0.domain) {
    throw new Error('Auth0 domain is required');
  }

  if (!config.auth0.audience) {
    throw new Error('Auth0 audience is required');
  }

  if (!config.auth0.issuer) {
    throw new Error('Auth0 issuer is required');
  }

  if (config.cache.validationDuration < 0) {
    throw new Error('Validation cache duration must be positive');
  }

  if (config.bruteForce.threshold < 1) {
    throw new Error('Brute force threshold must be at least 1');
  }

  if (config.bruteForce.window < 1000) {
    throw new Error('Brute force window must be at least 1 second');
  }

  if (config.audit.maxHistorySize < 100) {
    throw new Error('Audit history size must be at least 100');
  }
}

/**
 * Get default authentication configuration
 */
export function getDefaultAuthConfig(): AuthConfig {
  return {
    auth0: {
      domain: 'your-tenant.auth0.com',
      audience: 'https://api.cloudtolocalllm.com',
      issuer: 'https://your-tenant.auth0.com/',
    },
    cache: {
      validationDuration: 5 * 60 * 1000, // 5 minutes
      jwksDuration: 60 * 60 * 1000, // 1 hour
    },
    bruteForce: {
      threshold: 5,
      window: 5 * 60 * 1000, // 5 minutes
      blockDuration: 60 * 60 * 1000, // 1 hour
    },
    audit: {
      maxHistorySize: 10000,
      retentionDays: 90,
    },
  };
}
