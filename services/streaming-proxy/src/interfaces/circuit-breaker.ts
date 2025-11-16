/**
 * Circuit Breaker Interface
 * Implements circuit breaker pattern for fault tolerance
 */

export enum CircuitState {
  CLOSED = 'closed',
  OPEN = 'open',
  HALF_OPEN = 'half_open',
}

export interface CircuitBreakerConfig {
  failureThreshold: number;
  successThreshold: number;
  timeout: number;
  resetTimeout: number;
}

export interface CircuitBreakerMetrics {
  state: CircuitState;
  failureCount: number;
  successCount: number;
  lastFailureTime?: Date;
  lastStateChange: Date;
}

export interface CircuitBreaker {
  /**
   * Execute operation with circuit breaker protection
   */
  execute<T>(operation: () => Promise<T>): Promise<T>;

  /**
   * Get current circuit state
   */
  getState(): CircuitState;

  /**
   * Configure circuit breaker
   */
  configure(config: CircuitBreakerConfig): void;

  /**
   * Manually open circuit
   */
  open(): void;

  /**
   * Manually close circuit
   */
  close(): void;

  /**
   * Reset circuit breaker
   */
  reset(): void;

  /**
   * Get circuit breaker metrics
   */
  getMetrics(): CircuitBreakerMetrics;
}
