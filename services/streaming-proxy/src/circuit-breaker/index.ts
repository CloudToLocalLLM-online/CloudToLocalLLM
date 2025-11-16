/**
 * Circuit Breaker Module
 * 
 * Exports all circuit breaker components for fault tolerance.
 */

export { CircuitBreakerImpl } from './circuit-breaker-impl';
export {
  withCircuitBreaker,
  wrapWithCircuitBreaker,
  CircuitBreakerProtected,
  executeBatch,
  executeWithRetry,
  isCircuitHealthy,
  getCircuitStatus,
  CircuitBreakerOpenError,
} from './circuit-breaker-wrapper';
export {
  AutomaticResetManager,
  createResetManager,
  type ResetManagerConfig,
  type ResetAttempt,
} from './automatic-reset-manager';
export {
  CircuitBreakerMetricsCollector,
  globalMetricsCollector,
  type CircuitBreakerMetricsSnapshot,
  type StateChangeEvent,
} from './circuit-breaker-metrics';

// Re-export interfaces
export {
  CircuitBreaker,
  CircuitBreakerConfig,
  CircuitBreakerMetrics,
  CircuitState,
} from '../interfaces/circuit-breaker';
