/**
 * Circuit Breaker Pattern Implementation
 * 
 * Prevents cascading failures by monitoring service calls and failing fast
 * when a service is unavailable.
 * 
 * States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Service is failing, requests fail immediately
 * - HALF_OPEN: Testing if service has recovered, limited requests allowed
 */

export class CircuitBreaker {
  constructor(options = {}) {
    this.name = options.name || 'CircuitBreaker';
    this.failureThreshold = options.failureThreshold || 5;
    this.successThreshold = options.successThreshold || 2;
    this.timeout = options.timeout || 60000; // 60 seconds
    this.onStateChange = options.onStateChange || (() => {});

    // State management
    this.state = 'CLOSED';
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.nextAttemptTime = null;

    // Metrics
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      rejectedRequests: 0,
      stateChanges: [],
    };
  }

  /**
   * Execute a function through the circuit breaker
   * @param {Function} fn - The function to execute
   * @param {*} context - The context to bind to the function
   * @param {Array} args - Arguments to pass to the function
   * @returns {Promise} - The result of the function or rejection
   */
  async execute(fn, context = null, args = []) {
    this.metrics.totalRequests++;

    // Check if circuit should transition to HALF_OPEN
    if (this.state === 'OPEN' && this.shouldAttemptReset()) {
      this.transitionTo('HALF_OPEN');
    }

    // Reject if circuit is OPEN
    if (this.state === 'OPEN') {
      this.metrics.rejectedRequests++;
      const error = new Error(`Circuit breaker is OPEN for ${this.name}`);
      error.code = 'CIRCUIT_BREAKER_OPEN';
      throw error;
    }

    try {
      const result = await fn.apply(context, args);
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  /**
   * Record a successful request
   */
  onSuccess() {
    this.metrics.successfulRequests++;
    this.failureCount = 0;

    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.transitionTo('CLOSED');
      }
    }
  }

  /**
   * Record a failed request
   */
  onFailure() {
    this.metrics.failedRequests++;
    this.lastFailureTime = Date.now();
    this.failureCount++;

    if (this.state === 'HALF_OPEN') {
      this.transitionTo('OPEN');
    } else if (this.state === 'CLOSED' && this.failureCount >= this.failureThreshold) {
      this.transitionTo('OPEN');
    }
  }

  /**
   * Check if enough time has passed to attempt reset
   */
  shouldAttemptReset() {
    if (!this.lastFailureTime) return false;
    return Date.now() - this.lastFailureTime >= this.timeout;
  }

  /**
   * Transition to a new state
   */
  transitionTo(newState) {
    if (this.state === newState) return;

    const oldState = this.state;
    this.state = newState;
    this.successCount = 0;

    // Record state change
    this.metrics.stateChanges.push({
      from: oldState,
      to: newState,
      timestamp: new Date().toISOString(),
    });

    // Notify listeners
    this.onStateChange({
      name: this.name,
      oldState,
      newState,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Get current state
   */
  getState() {
    return this.state;
  }

  /**
   * Get metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
    };
  }

  /**
   * Reset the circuit breaker to CLOSED state
   */
  reset() {
    this.transitionTo('CLOSED');
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
  }

  /**
   * Manually open the circuit breaker
   */
  open() {
    this.transitionTo('OPEN');
  }

  /**
   * Manually close the circuit breaker
   */
  close() {
    this.transitionTo('CLOSED');
    this.failureCount = 0;
    this.successCount = 0;
  }
}

/**
 * Circuit Breaker Manager for managing multiple circuit breakers
 */
export class CircuitBreakerManager {
  constructor() {
    this.breakers = new Map();
  }

  /**
   * Create or get a circuit breaker
   */
  getOrCreate(name, options = {}) {
    if (!this.breakers.has(name)) {
      this.breakers.set(name, new CircuitBreaker({ name, ...options }));
    }
    return this.breakers.get(name);
  }

  /**
   * Get a circuit breaker by name
   */
  get(name) {
    return this.breakers.get(name);
  }

  /**
   * Get all circuit breakers
   */
  getAll() {
    return Array.from(this.breakers.values());
  }

  /**
   * Get metrics for all circuit breakers
   */
  getAllMetrics() {
    const metrics = {};
    for (const [name, breaker] of this.breakers) {
      metrics[name] = breaker.getMetrics();
    }
    return metrics;
  }

  /**
   * Reset all circuit breakers
   */
  resetAll() {
    for (const breaker of this.breakers.values()) {
      breaker.reset();
    }
  }

  /**
   * Remove a circuit breaker
   */
  remove(name) {
    this.breakers.delete(name);
  }
}

// Export singleton instance
export const circuitBreakerManager = new CircuitBreakerManager();
