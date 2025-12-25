/**
 * Authentication Configuration
 * Centralized configuration for authentication middleware
 */

export interface AuthConfig {
  auth0: {
    jwksUri: string;
    audience: string;
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
  const auth0Audience = process.env.AUTH0_AUDIENCE;
  const auth0Domain = process.env.AUTH0_DOMAIN;
  const auth0IssuerUrl = process.env.AUTH0_ISSUER_URL;

  // Derive JWKS URI with no hardcoded fallback
  const auth0JwksUri =
    process.env.AUTH0_JWKS_URI ||
    (auth0IssuerUrl ? `${auth0IssuerUrl}/.well-known/jwks.json` : null) ||
    (auth0Domain ? `https://${auth0Domain}/.well-known/jwks.json` : null);

  if (!auth0Audience || !auth0JwksUri) {
    const missing = [];
    if (!auth0Audience) missing.push('AUTH0_AUDIENCE');
    if (!auth0JwksUri)
      missing.push('AUTH0_JWKS_URI (or AUTH0_DOMAIN/AUTH0_ISSUER_URL)');
    throw new Error(
      `CRITICAL: Missing Auth0 configuration: ${missing.join(
        ', '
      )}. Zero-fallback policy in effect.`
    );
  }

  return {
    auth0: {
      jwksUri: auth0JwksUri,
      audience: auth0Audience,
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
  // Return configuration based on environment without fallbacks
  return loadAuthConfig();
}