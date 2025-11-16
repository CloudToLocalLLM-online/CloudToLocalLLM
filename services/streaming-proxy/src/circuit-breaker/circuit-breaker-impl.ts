/**
 * Circuit Breaker Implementation
 * 
 * Implements the circuit breaker pattern to prevent cascading failures by monitoring
 * operation success/failure rates and stopping requests when failures exceed a threshold.
 * 
 * ## State Machine
 * 
 * The circuit breaker transitions between three states:
 * 
 * 1. **CLOSED** (Normal Operation)
 *    - Requests pass through normally
 *    - Failures are counted
 *    - When failures >= failureThreshold: transition to OPEN
 * 
 * 2. **OPEN** (Blocking Requests)
 *    - All requests are rejected immediately
 *    - Prevents cascading failures to failing service
 *    - After resetTimeout: transition to HALF_OPEN
 * 
 * 3. **HALF_OPEN** (Testing Recovery)
 *    - Limited requests allowed to test if service recovered
 *    - If successes >= successThreshold: transition to CLOSED
 *    - If any failure occurs: transition back to OPEN
 * 
 * ## Configuration
 * 
 * - `failureThreshold`: Number of consecutive failures before opening (e.g., 5)
 * - `successThreshold`: Number of consecutive successes in HALF_OPEN before closing (e.g., 2)
 * - `timeout`: Maximum time for individual operations (e.g., 30000ms)
 * - `resetTimeout`: Time to wait before attempting recovery (e.g., 60000ms)
 * 
 * ## Usage Example
 * 
 * ```typescript
 * const breaker = new CircuitBreakerImpl({
 *   failureThreshold: 5,
 *   successThreshold: 2,
 *   timeout: 30000,
 *   resetTimeout: 60000,
 * });
 * 
 * try {
 *   const result = await breaker.execute(async () => {
 *     return await someUnreliableService.call();
 *   });
 * } catch (error) {
 *   if (error.message.includes('Circuit breaker is OPEN')) {
 *     // Service is down, use fallback
 *   }
 * }
 * ```
 * 
 * ## Events
 * 
 * - `stateChange`: Emitted when state transitions
 * - `success`: Emitted on successful operation
 * - `failure`: Emitted on failed operation
 * - `configured`: Emitted when configuration changes
 * - `reset`: Emitted when circuit is reset
 * 
 * Requirements: 5.7, 5.8
 */

import {
  CircuitBreaker,
  CircuitBreakerConfig,
  CircuitBreakerMetrics,
  CircuitState,
} from '../interfaces/circuit-breaker';
import { EventEmitter } from 'events';

/**
 * Circuit Breaker Implementation
 * 
 * Prevents cascading failures by monitoring operation success/failure rates
 * and stopping requests when failures exceed a threshold.
 */
export class CircuitBreakerImpl extends EventEmitter implements CircuitBreaker {
  /** Current circuit state (CLOSED, OPEN, or HALF_OPEN) */
  private state: CircuitState = CircuitState.CLOSED;
  
  /** Number of consecutive failures in CLOSED state */
  private failureCount: number = 0;
  
  /** Number of consecutive successes in HALF_OPEN state */
  private successCount: number = 0;
  
  /** Timestamp of the last failure */
  private lastFailureTime?: Date;
  
  /** Timestamp of the last state transition */
  private lastStateChange: Date = new Date();
  
  /** Timer for automatic reset from OPEN to HALF_OPEN */
  private resetTimer?: NodeJS.Timeout;
  
  /** Circuit breaker configuration */
  private config: CircuitBreakerConfig;

  /**
   * Create a new circuit breaker instance
   * 
   * @param config - Circuit breaker configuration
   * @throws Error if configuration is invalid
   */
  constructor(config: CircuitBreakerConfig) {
    super();
    this.config = config;
  }

  /**
   * Execute an operation with circuit breaker protection
   * 
   * Wraps the operation with timeout and failure tracking. If the circuit is OPEN,
   * rejects immediately without executing the operation.
   * 
   * @template T - The return type of the operation
   * @param operation - The async operation to execute
   * @returns Promise resolving to operation result
   * @throws Error if circuit is OPEN, operation times out, or operation fails
   * 
   * @example
   * ```typescript
   * try {
   *   const result = await breaker.execute(async () => {
   *     return await sshConnection.forward(request);
   *   });
   * } catch (error) {
   *   if (error.message.includes('Circuit breaker is OPEN')) {
   *     // Use fallback or queue request
   *   }
   * }
   * ```
   */
  async execute<T>(operation: () => Promise<T>): Promise<T> {
    // Check if circuit is open - fail fast without executing operation
    if (this.state === CircuitState.OPEN) {
      throw new Error('Circuit breaker is OPEN - requests are blocked');
    }

    // Create timeout promise that rejects after configured timeout
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => {
        reject(new Error('Operation timeout'));
      }, this.config.timeout);
    });

    try {
      // Race between operation and timeout - whichever completes first wins
      const result = await Promise.race([operation(), timeoutPromise]);
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  /**
   * Get current circuit state
   * 
   * @returns Current state (CLOSED, OPEN, or HALF_OPEN)
   */
  getState(): CircuitState {
    return this.state;
  }

  /**
   * Configure circuit breaker settings
   * 
   * Updates the circuit breaker configuration and emits a 'configured' event.
   * 
   * @param config - New circuit breaker configuration
   */
  configure(config: CircuitBreakerConfig): void {
    this.config = config;
    this.emit('configured', config);
  }

  /**
   * Manually open the circuit
   * 
   * Transitions to OPEN state, blocking all requests. Useful for manual intervention
   * when you know the service is down.
   */
  open(): void {
    this.transitionTo(CircuitState.OPEN);
  }

  /**
   * Manually close the circuit
   * 
   * Transitions to CLOSED state, allowing requests to pass through. Resets failure
   * and success counters.
   */
  close(): void {
    this.transitionTo(CircuitState.CLOSED);
    this.failureCount = 0;
    this.successCount = 0;
  }

  /**
   * Reset circuit breaker to initial state
   * 
   * Clears all counters and timers, returning to CLOSED state. Emits 'reset' event.
   */
  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = undefined;
    this.lastStateChange = new Date();
    this.clearResetTimer();
    this.emit('reset');
  }

  /**
   * Get circuit breaker metrics
   * 
   * Returns current state and counters for monitoring and debugging.
   * 
   * @returns Current metrics including state, failure/success counts, and timestamps
   */
  getMetrics(): CircuitBreakerMetrics {
    return {
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
      lastFailureTime: this.lastFailureTime,
      lastStateChange: this.lastStateChange,
    };
  }

  /**
   * Handle successful operation
   * 
   * Resets failure counter. In HALF_OPEN state, increments success counter
   * and transitions to CLOSED if threshold is reached.
   * 
   * @private
   */
  private onSuccess(): void {
    this.failureCount = 0;

    if (this.state === CircuitState.HALF_OPEN) {
      this.successCount++;
      
      // Check if we've reached success threshold to close the circuit
      if (this.successCount >= this.config.successThreshold) {
        this.transitionTo(CircuitState.CLOSED);
        this.successCount = 0;
      }
    }

    this.emit('success', this.getMetrics());
  }

  /**
   * Handle failed operation
   * 
   * Increments failure counter. In CLOSED state, opens circuit if threshold is reached.
   * In HALF_OPEN state, immediately reopens circuit.
   * 
   * @private
   */
  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = new Date();

    if (this.state === CircuitState.HALF_OPEN) {
      // Any failure in half-open state reopens the circuit
      this.transitionTo(CircuitState.OPEN);
      this.successCount = 0;
    } else if (this.state === CircuitState.CLOSED) {
      // Check if we've reached failure threshold to open the circuit
      if (this.failureCount >= this.config.failureThreshold) {
        this.transitionTo(CircuitState.OPEN);
      }
    }

    this.emit('failure', this.getMetrics());
  }

  /**
   * Transition to a new state
   * 
   * Handles state transitions, emits events, and schedules automatic recovery.
   * 
   * @private
   * @param newState - The state to transition to
   */
  private transitionTo(newState: CircuitState): void {
    const oldState = this.state;
    this.state = newState;
    this.lastStateChange = new Date();

    // Clear any existing reset timer
    this.clearResetTimer();

    // Schedule automatic reset if opening
    if (newState === CircuitState.OPEN) {
      this.scheduleReset();
    }

    this.emit('stateChange', {
      from: oldState,
      to: newState,
      timestamp: this.lastStateChange,
    });
  }

  /**
   * Schedule automatic reset to half-open state
   * 
   * After resetTimeout milliseconds, transitions from OPEN to HALF_OPEN
   * to test if the service has recovered.
   * 
   * @private
   */
  private scheduleReset(): void {
    this.resetTimer = setTimeout(() => {
      this.transitionTo(CircuitState.HALF_OPEN);
      this.failureCount = 0;
      this.successCount = 0;
    }, this.config.resetTimeout);
  }

  /**
   * Clear reset timer
   * 
   * Cancels any pending automatic reset.
   * 
   * @private
   */
  private clearResetTimer(): void {
    if (this.resetTimer) {
      clearTimeout(this.resetTimer);
      this.resetTimer = undefined;
    }
  }
}
