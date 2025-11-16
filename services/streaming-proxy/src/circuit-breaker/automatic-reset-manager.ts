/**
 * Automatic Reset Manager
 * 
 * Manages automatic reset and recovery testing for circuit breakers.
 * Handles transition to half-open state and recovery validation.
 * 
 * Requirements: 5.8
 */

import { CircuitBreaker, CircuitState } from '../interfaces/circuit-breaker';
import { EventEmitter } from 'events';

export interface ResetManagerConfig {
  /**
   * Time to wait before attempting reset (milliseconds)
   */
  resetTimeout: number;

  /**
   * Number of successful requests needed to close circuit
   */
  successThreshold: number;

  /**
   * Enable automatic reset
   */
  enabled: boolean;
}

export interface ResetAttempt {
  timestamp: Date;
  success: boolean;
  reason?: string;
}

/**
 * Manages automatic reset and recovery for circuit breakers
 */
export class AutomaticResetManager extends EventEmitter {
  private circuitBreaker: CircuitBreaker;
  private config: ResetManagerConfig;
  private resetTimer?: NodeJS.Timeout;
  private resetAttempts: ResetAttempt[] = [];
  private isMonitoring: boolean = false;

  constructor(circuitBreaker: CircuitBreaker, config: ResetManagerConfig) {
    super();
    this.circuitBreaker = circuitBreaker;
    this.config = config;
  }

  /**
   * Start monitoring circuit breaker for automatic reset
   */
  start(): void {
    if (this.isMonitoring) {
      return;
    }

    this.isMonitoring = true;

    // Listen to circuit breaker state changes
    if (this.circuitBreaker instanceof EventEmitter) {
      this.circuitBreaker.on('stateChange', this.handleStateChange.bind(this));
    }

    this.emit('started');
  }

  /**
   * Stop monitoring
   */
  stop(): void {
    this.isMonitoring = false;
    this.clearResetTimer();

    if (this.circuitBreaker instanceof EventEmitter) {
      this.circuitBreaker.removeListener(
        'stateChange',
        this.handleStateChange.bind(this)
      );
    }

    this.emit('stopped');
  }

  /**
   * Handle circuit breaker state changes
   */
  private handleStateChange(event: {
    from: CircuitState;
    to: CircuitState;
    timestamp: Date;
  }): void {
    const { from, to } = event;

    // When circuit opens, schedule automatic reset
    if (to === CircuitState.OPEN && this.config.enabled) {
      this.scheduleReset();
    }

    // When circuit transitions to half-open, start recovery testing
    if (to === CircuitState.HALF_OPEN) {
      this.startRecoveryTesting();
    }

    // When circuit closes, record successful recovery
    if (from === CircuitState.HALF_OPEN && to === CircuitState.CLOSED) {
      this.recordResetAttempt(true, 'Recovery successful');
    }

    // When circuit reopens from half-open, record failed recovery
    if (from === CircuitState.HALF_OPEN && to === CircuitState.OPEN) {
      this.recordResetAttempt(false, 'Recovery failed');
    }
  }

  /**
   * Schedule automatic reset to half-open state
   */
  private scheduleReset(): void {
    this.clearResetTimer();

    this.resetTimer = setTimeout(() => {
      this.attemptReset();
    }, this.config.resetTimeout);

    this.emit('resetScheduled', {
      timeout: this.config.resetTimeout,
      scheduledAt: new Date(),
    });
  }

  /**
   * Attempt to reset circuit to half-open state
   */
  private attemptReset(): void {
    const currentState = this.circuitBreaker.getState();

    if (currentState !== CircuitState.OPEN) {
      return;
    }

    // Transition to half-open for recovery testing
    // Note: The actual transition is handled by CircuitBreakerImpl
    // This just emits an event for monitoring
    this.emit('resetAttempted', {
      timestamp: new Date(),
      previousState: currentState,
    });
  }

  /**
   * Start recovery testing in half-open state
   */
  private startRecoveryTesting(): void {
    this.emit('recoveryTestingStarted', {
      timestamp: new Date(),
      successThreshold: this.config.successThreshold,
    });
  }

  /**
   * Record a reset attempt
   */
  private recordResetAttempt(success: boolean, reason?: string): void {
    const attempt: ResetAttempt = {
      timestamp: new Date(),
      success,
      reason,
    };

    this.resetAttempts.push(attempt);

    // Keep only last 100 attempts
    if (this.resetAttempts.length > 100) {
      this.resetAttempts.shift();
    }

    this.emit('resetAttemptRecorded', attempt);
  }

  /**
   * Get reset attempt history
   */
  getResetHistory(): ResetAttempt[] {
    return [...this.resetAttempts];
  }

  /**
   * Get reset statistics
   */
  getResetStatistics(): {
    totalAttempts: number;
    successfulAttempts: number;
    failedAttempts: number;
    successRate: number;
    lastAttempt?: ResetAttempt;
  } {
    const totalAttempts = this.resetAttempts.length;
    const successfulAttempts = this.resetAttempts.filter((a) => a.success)
      .length;
    const failedAttempts = totalAttempts - successfulAttempts;
    const successRate =
      totalAttempts > 0 ? successfulAttempts / totalAttempts : 0;
    const lastAttempt =
      this.resetAttempts.length > 0
        ? this.resetAttempts[this.resetAttempts.length - 1]
        : undefined;

    return {
      totalAttempts,
      successfulAttempts,
      failedAttempts,
      successRate,
      lastAttempt,
    };
  }

  /**
   * Update configuration
   */
  updateConfig(config: Partial<ResetManagerConfig>): void {
    this.config = { ...this.config, ...config };
    this.emit('configUpdated', this.config);
  }

  /**
   * Clear reset timer
   */
  private clearResetTimer(): void {
    if (this.resetTimer) {
      clearTimeout(this.resetTimer);
      this.resetTimer = undefined;
    }
  }

  /**
   * Force immediate reset attempt
   */
  forceReset(): void {
    this.clearResetTimer();
    this.attemptReset();
  }
}

/**
 * Create an automatic reset manager for a circuit breaker
 */
export function createResetManager(
  circuitBreaker: CircuitBreaker,
  config: ResetManagerConfig
): AutomaticResetManager {
  return new AutomaticResetManager(circuitBreaker, config);
}
