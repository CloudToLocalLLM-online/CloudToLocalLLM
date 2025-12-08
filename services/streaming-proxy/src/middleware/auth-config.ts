/**
 * Authentication Configuration
 * Centralized configuration for authentication middleware
 */

export interface AuthConfig {
  supabase: {
    url: string;
  };
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
  const supabaseUrl = process.env.SUPABASE_URL;

  // if (!supabaseUrl) {
  //   throw new Error('SUPABASE_URL environment variable is required');
  // }

  return {
    supabase: {
      url: supabaseUrl || 'unused',
    },
    auth0: {
      jwksUri: process.env.AUTH0_JWKS_URI || 'https://cloudtolocalllm.auth0.com/.well-known/jwks.json',
      audience: process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.com',
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
  // Supabase URL check removed as we are migrating to Entra
  // if (!config.supabase.url) {
  //   throw new Error('Supabase URL is required');
  // }

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
    supabase: {
      url: 'https://your-project.supabase.co',
    },
    auth0: {
      jwksUri: 'https://cloudtolocalllm.auth0.com/.well-known/jwks.json',
      audience: 'https://api.cloudtolocalllm.com',
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
