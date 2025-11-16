/**
 * Circuit Breaker Execution Wrapper
 * 
 * Provides utility functions to wrap operations with circuit breaker protection.
 * Tracks success/failure counts and manages state transitions.
 * 
 * Requirements: 5.7
 */

import { CircuitBreaker, CircuitState } from '../interfaces/circuit-breaker';

/**
 * Error thrown when circuit breaker is open
 */
export class CircuitBreakerOpenError extends Error {
  constructor(message: string = 'Circuit breaker is open') {
    super(message);
    this.name = 'CircuitBreakerOpenError';
  }
}

/**
 * Wrap an async operation with circuit breaker protection
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @param operation - The operation to execute
 * @param fallback - Optional fallback function to call when circuit is open
 * @returns Promise resolving to operation result or fallback result
 */
export async function withCircuitBreaker<T>(
  circuitBreaker: CircuitBreaker,
  operation: () => Promise<T>,
  fallback?: () => Promise<T>
): Promise<T> {
  try {
    return await circuitBreaker.execute(operation);
  } catch (error) {
    // If circuit is open and fallback is provided, use fallback
    if (
      error instanceof Error &&
      error.message.includes('Circuit breaker is OPEN') &&
      fallback
    ) {
      return await fallback();
    }
    throw error;
  }
}

/**
 * Create a wrapped function that automatically uses circuit breaker
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @param fn - The function to wrap
 * @returns Wrapped function with circuit breaker protection
 */
export function wrapWithCircuitBreaker<TArgs extends any[], TResult>(
  circuitBreaker: CircuitBreaker,
  fn: (...args: TArgs) => Promise<TResult>
): (...args: TArgs) => Promise<TResult> {
  return async (...args: TArgs): Promise<TResult> => {
    return await circuitBreaker.execute(() => fn(...args));
  };
}

/**
 * Circuit breaker decorator for class methods
 * 
 * Usage:
 * ```typescript
 * class MyService {
 *   @CircuitBreakerProtected(myCircuitBreaker)
 *   async myMethod() {
 *     // method implementation
 *   }
 * }
 * ```
 */
export function CircuitBreakerProtected(circuitBreaker: CircuitBreaker) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      return await circuitBreaker.execute(() =>
        originalMethod.apply(this, args)
      );
    };

    return descriptor;
  };
}

/**
 * Batch executor with circuit breaker protection
 * Executes multiple operations with circuit breaker, stopping on first failure
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @param operations - Array of operations to execute
 * @returns Promise resolving to array of results
 */
export async function executeBatch<T>(
  circuitBreaker: CircuitBreaker,
  operations: Array<() => Promise<T>>
): Promise<T[]> {
  const results: T[] = [];

  for (const operation of operations) {
    const result = await circuitBreaker.execute(operation);
    results.push(result);
  }

  return results;
}

/**
 * Retry executor with circuit breaker protection
 * Retries operation with exponential backoff if it fails
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @param operation - The operation to execute
 * @param maxRetries - Maximum number of retries
 * @param baseDelay - Base delay in milliseconds for exponential backoff
 * @returns Promise resolving to operation result
 */
export async function executeWithRetry<T>(
  circuitBreaker: CircuitBreaker,
  operation: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await circuitBreaker.execute(operation);
    } catch (error) {
      lastError = error as Error;

      // Don't retry if circuit is open
      if (
        error instanceof Error &&
        error.message.includes('Circuit breaker is OPEN')
      ) {
        throw error;
      }

      // Don't delay after last attempt
      if (attempt < maxRetries) {
        const delay = baseDelay * Math.pow(2, attempt);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError || new Error('Operation failed after retries');
}

/**
 * Check if circuit breaker is healthy (closed or half-open)
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @returns True if circuit is healthy
 */
export function isCircuitHealthy(circuitBreaker: CircuitBreaker): boolean {
  const state = circuitBreaker.getState();
  return state === CircuitState.CLOSED || state === CircuitState.HALF_OPEN;
}

/**
 * Get human-readable circuit breaker status
 * 
 * @param circuitBreaker - The circuit breaker instance
 * @returns Status string
 */
export function getCircuitStatus(circuitBreaker: CircuitBreaker): string {
  const metrics = circuitBreaker.getMetrics();
  const state = metrics.state;

  switch (state) {
    case CircuitState.CLOSED:
      return 'Healthy - All requests allowed';
    case CircuitState.OPEN:
      return `Unhealthy - Requests blocked (${metrics.failureCount} failures)`;
    case CircuitState.HALF_OPEN:
      return `Testing - Limited requests allowed (${metrics.successCount} successes)`;
    default:
      return 'Unknown';
  }
}
