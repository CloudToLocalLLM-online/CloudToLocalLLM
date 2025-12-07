/**
 * Authentication Configuration
 * Centralized configuration for authentication middleware
 */

export interface AuthConfig {
  supabase: {
    url: string;
  };
  entra: {
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
    entra: {
      jwksUri: process.env.ENTRA_JWKS_URI || 'https://auth.cloudtolocalllm.online/cloudtolocalllm.onmicrosoft.com/b2c_1_sign_up_in/discovery/v2.0/keys',
      audience: process.env.ENTRA_AUDIENCE || '1a72fdf6-4e48-4cb8-943b-a4a4ac513148',
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
    entra: {
      jwksUri: 'https://auth.cloudtolocalllm.online/cloudtolocalllm.onmicrosoft.com/b2c_1_sign_up_in/discovery/v2.0/keys',
      audience: '1a72fdf6-4e48-4cb8-943b-a4a4ac513148',
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
