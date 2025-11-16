/**
 * Circuit Breaker Metrics
 * 
 * Tracks and exposes circuit breaker metrics for monitoring.
 * Provides Prometheus-compatible metrics format.
 * 
 * Requirements: 5.7, 11.1
 */

import {
  CircuitBreaker,
  CircuitBreakerMetrics,
  CircuitState,
} from '../interfaces/circuit-breaker';

export interface CircuitBreakerMetricsSnapshot {
  name: string;
  state: CircuitState;
  failureCount: number;
  successCount: number;
  lastFailureTime?: Date;
  lastStateChange: Date;
  stateChangeHistory: StateChangeEvent[];
  uptime: number;
  totalRequests: number;
  totalFailures: number;
  totalSuccesses: number;
}

export interface StateChangeEvent {
  timestamp: Date;
  fromState: CircuitState;
  toState: CircuitState;
}

/**
 * Metrics collector for circuit breakers
 */
export class CircuitBreakerMetricsCollector {
  private circuitBreakers: Map<string, CircuitBreaker> = new Map();
  private stateChangeHistory: Map<string, StateChangeEvent[]> = new Map();
  private requestCounts: Map<string, { total: number; failures: number; successes: number }> = new Map();
  private startTime: Date = new Date();

  /**
   * Register a circuit breaker for metrics collection
   */
  register(name: string, circuitBreaker: CircuitBreaker): void {
    this.circuitBreakers.set(name, circuitBreaker);
    this.stateChangeHistory.set(name, []);
    this.requestCounts.set(name, { total: 0, failures: 0, successes: 0 });

    // Listen to events if circuit breaker is an EventEmitter
    if ('on' in circuitBreaker && typeof circuitBreaker.on === 'function') {
      const emitter = circuitBreaker as any;

      emitter.on('stateChange', (event: any) => {
        this.recordStateChange(name, event);
      });

      emitter.on('success', () => {
        this.recordSuccess(name);
      });

      emitter.on('failure', () => {
        this.recordFailure(name);
      });
    }
  }

  /**
   * Unregister a circuit breaker
   */
  unregister(name: string): void {
    this.circuitBreakers.delete(name);
    this.stateChangeHistory.delete(name);
    this.requestCounts.delete(name);
  }

  /**
   * Record a state change
   */
  private recordStateChange(name: string, event: any): void {
    const history = this.stateChangeHistory.get(name) || [];
    history.push({
      timestamp: event.timestamp || new Date(),
      fromState: event.from,
      toState: event.to,
    });

    // Keep only last 100 state changes
    if (history.length > 100) {
      history.shift();
    }

    this.stateChangeHistory.set(name, history);
  }

  /**
   * Record a successful request
   */
  private recordSuccess(name: string): void {
    const counts = this.requestCounts.get(name);
    if (counts) {
      counts.total++;
      counts.successes++;
    }
  }

  /**
   * Record a failed request
   */
  private recordFailure(name: string): void {
    const counts = this.requestCounts.get(name);
    if (counts) {
      counts.total++;
      counts.failures++;
    }
  }

  /**
   * Get metrics for a specific circuit breaker
   */
  getMetrics(name: string): CircuitBreakerMetricsSnapshot | null {
    const circuitBreaker = this.circuitBreakers.get(name);
    if (!circuitBreaker) {
      return null;
    }

    const metrics = circuitBreaker.getMetrics();
    const history = this.stateChangeHistory.get(name) || [];
    const counts = this.requestCounts.get(name) || { total: 0, failures: 0, successes: 0 };
    const uptime = Date.now() - this.startTime.getTime();

    return {
      name,
      state: metrics.state,
      failureCount: metrics.failureCount,
      successCount: metrics.successCount,
      lastFailureTime: metrics.lastFailureTime,
      lastStateChange: metrics.lastStateChange,
      stateChangeHistory: history,
      uptime,
      totalRequests: counts.total,
      totalFailures: counts.failures,
      totalSuccesses: counts.successes,
    };
  }

  /**
   * Get metrics for all circuit breakers
   */
  getAllMetrics(): CircuitBreakerMetricsSnapshot[] {
    const metrics: CircuitBreakerMetricsSnapshot[] = [];

    for (const name of this.circuitBreakers.keys()) {
      const snapshot = this.getMetrics(name);
      if (snapshot) {
        metrics.push(snapshot);
      }
    }

    return metrics;
  }

  /**
   * Export metrics in Prometheus format
   */
  exportPrometheusMetrics(): string {
    const lines: string[] = [];

    // Circuit breaker state (0=closed, 1=half_open, 2=open)
    lines.push('# HELP circuit_breaker_state Current state of circuit breaker');
    lines.push('# TYPE circuit_breaker_state gauge');
    for (const [name, breaker] of this.circuitBreakers.entries()) {
      const state = breaker.getState();
      const stateValue = state === CircuitState.CLOSED ? 0 : state === CircuitState.HALF_OPEN ? 1 : 2;
      lines.push(`circuit_breaker_state{name="${name}",state="${state}"} ${stateValue}`);
    }

    // Failure count
    lines.push('# HELP circuit_breaker_failures_total Total number of failures');
    lines.push('# TYPE circuit_breaker_failures_total counter');
    for (const [name, counts] of this.requestCounts.entries()) {
      lines.push(`circuit_breaker_failures_total{name="${name}"} ${counts.failures}`);
    }

    // Success count
    lines.push('# HELP circuit_breaker_successes_total Total number of successes');
    lines.push('# TYPE circuit_breaker_successes_total counter');
    for (const [name, counts] of this.requestCounts.entries()) {
      lines.push(`circuit_breaker_successes_total{name="${name}"} ${counts.successes}`);
    }

    // Total requests
    lines.push('# HELP circuit_breaker_requests_total Total number of requests');
    lines.push('# TYPE circuit_breaker_requests_total counter');
    for (const [name, counts] of this.requestCounts.entries()) {
      lines.push(`circuit_breaker_requests_total{name="${name}"} ${counts.total}`);
    }

    // State change count
    lines.push('# HELP circuit_breaker_state_changes_total Total number of state changes');
    lines.push('# TYPE circuit_breaker_state_changes_total counter');
    for (const [name, history] of this.stateChangeHistory.entries()) {
      lines.push(`circuit_breaker_state_changes_total{name="${name}"} ${history.length}`);
    }

    // Time since last state change
    lines.push('# HELP circuit_breaker_last_state_change_seconds Seconds since last state change');
    lines.push('# TYPE circuit_breaker_last_state_change_seconds gauge');
    for (const [name, breaker] of this.circuitBreakers.entries()) {
      const metrics = breaker.getMetrics();
      const secondsSinceChange = (Date.now() - metrics.lastStateChange.getTime()) / 1000;
      lines.push(`circuit_breaker_last_state_change_seconds{name="${name}"} ${secondsSinceChange.toFixed(2)}`);
    }

    return lines.join('\n');
  }

  /**
   * Export metrics in JSON format
   */
  exportJsonMetrics(): any {
    return {
      timestamp: new Date().toISOString(),
      uptime: Date.now() - this.startTime.getTime(),
      circuitBreakers: this.getAllMetrics(),
    };
  }

  /**
   * Get summary statistics
   */
  getSummary(): {
    totalCircuitBreakers: number;
    openCircuits: number;
    closedCircuits: number;
    halfOpenCircuits: number;
    totalRequests: number;
    totalFailures: number;
    totalSuccesses: number;
    overallSuccessRate: number;
  } {
    let openCircuits = 0;
    let closedCircuits = 0;
    let halfOpenCircuits = 0;
    let totalRequests = 0;
    let totalFailures = 0;
    let totalSuccesses = 0;

    for (const [name, breaker] of this.circuitBreakers.entries()) {
      const state = breaker.getState();
      if (state === CircuitState.OPEN) openCircuits++;
      else if (state === CircuitState.CLOSED) closedCircuits++;
      else if (state === CircuitState.HALF_OPEN) halfOpenCircuits++;

      const counts = this.requestCounts.get(name);
      if (counts) {
        totalRequests += counts.total;
        totalFailures += counts.failures;
        totalSuccesses += counts.successes;
      }
    }

    const overallSuccessRate = totalRequests > 0 ? totalSuccesses / totalRequests : 0;

    return {
      totalCircuitBreakers: this.circuitBreakers.size,
      openCircuits,
      closedCircuits,
      halfOpenCircuits,
      totalRequests,
      totalFailures,
      totalSuccesses,
      overallSuccessRate,
    };
  }

  /**
   * Reset all metrics
   */
  reset(): void {
    for (const name of this.circuitBreakers.keys()) {
      this.stateChangeHistory.set(name, []);
      this.requestCounts.set(name, { total: 0, failures: 0, successes: 0 });
    }
    this.startTime = new Date();
  }
}

/**
 * Global metrics collector instance
 */
export const globalMetricsCollector = new CircuitBreakerMetricsCollector();
