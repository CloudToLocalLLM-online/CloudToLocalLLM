/**
 * OpenTelemetry Setup and Instrumentation
 * 
 * Provides helper functions to instrument key operations with OpenTelemetry spans.
 * Integrates with the tracer configuration for distributed tracing.
 * 
 * Requirements: 11.6
 */

import { trace, Span, SpanStatusCode } from '@opentelemetry/api';
import { getTracer, withSpan, addSpanAttributes, addSpanEvent, recordSpanException } from './tracer';

/**
 * Instrument WebSocket connection establishment
 * 
 * Requirement: 11.6
 */
export async function instrumentWebSocketConnection<T>(
  userId: string,
  connectionId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'websocket.connection',
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('connection.id', connectionId);
      span.setAttribute('connection.type', 'websocket');
      
      try {
        const result = await fn();
        span.addEvent('websocket.connected', {
          'user.id': userId,
          'connection.id': connectionId,
        });
        return result;
      } catch (error) {
        span.addEvent('websocket.connection_failed', {
          'user.id': userId,
          'connection.id': connectionId,
          'error.type': (error as Error).name,
        });
        throw error;
      }
    }
  );
}

/**
 * Instrument WebSocket disconnection
 * 
 * Requirement: 11.6
 */
export async function instrumentWebSocketDisconnection<T>(
  userId: string,
  connectionId: string,
  reason: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'websocket.disconnection',
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('connection.id', connectionId);
      span.setAttribute('disconnect.reason', reason);
      
      return await fn();
    }
  );
}

/**
 * Instrument request forwarding through SSH tunnel
 * 
 * Requirement: 11.6
 */
export async function instrumentRequestForward<T>(
  userId: string,
  requestId: string,
  endpoint: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'tunnel.forward_request',
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('request.id', requestId);
      span.setAttribute('request.endpoint', endpoint);
      
      const startTime = Date.now();
      
      try {
        const result = await fn();
        const latency = Date.now() - startTime;
        
        span.setAttribute('request.latency_ms', latency);
        span.setAttribute('request.status', 'success');
        
        return result;
      } catch (error) {
        const latency = Date.now() - startTime;
        span.setAttribute('request.latency_ms', latency);
        span.setAttribute('request.status', 'error');
        span.setAttribute('error.type', (error as Error).name);
        span.setAttribute('error.message', (error as Error).message);
        
        throw error;
      }
    }
  );
}

/**
 * Instrument SSH connection operations
 * 
 * Requirement: 11.6
 */
export async function instrumentSSHOperation<T>(
  operation: string,
  userId: string,
  connectionId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    `ssh.${operation}`,
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('connection.id', connectionId);
      span.setAttribute('ssh.operation', operation);
      
      const startTime = Date.now();
      
      try {
        const result = await fn();
        const duration = Date.now() - startTime;
        
        span.setAttribute('ssh.duration_ms', duration);
        span.setAttribute('ssh.status', 'success');
        
        return result;
      } catch (error) {
        const duration = Date.now() - startTime;
        span.setAttribute('ssh.duration_ms', duration);
        span.setAttribute('ssh.status', 'error');
        span.setAttribute('error.type', (error as Error).name);
        
        throw error;
      }
    }
  );
}

/**
 * Instrument SSH channel operations
 * 
 * Requirement: 11.6
 */
export async function instrumentSSHChannel<T>(
  operation: string,
  userId: string,
  channelId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    `ssh.channel.${operation}`,
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('channel.id', channelId);
      span.setAttribute('ssh.channel.operation', operation);
      
      return await fn();
    }
  );
}

/**
 * Instrument authentication operations
 * 
 * Requirement: 11.6
 */
export async function instrumentAuthentication<T>(
  userId: string | undefined,
  authMethod: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'auth.validate_token',
    async (span: Span) => {
      if (userId) {
        span.setAttribute('user.id', userId);
      }
      span.setAttribute('auth.method', authMethod);
      
      try {
        const result = await fn();
        span.setAttribute('auth.status', 'success');
        return result;
      } catch (error) {
        span.setAttribute('auth.status', 'failed');
        span.setAttribute('error.type', (error as Error).name);
        throw error;
      }
    }
  );
}

/**
 * Instrument rate limiting checks
 * 
 * Requirement: 11.6
 */
export async function instrumentRateLimitCheck<T>(
  userId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'rate_limit.check',
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      
      try {
        const result = await fn();
        span.setAttribute('rate_limit.status', 'allowed');
        return result;
      } catch (error) {
        span.setAttribute('rate_limit.status', 'exceeded');
        span.setAttribute('error.type', (error as Error).name);
        throw error;
      }
    }
  );
}

/**
 * Instrument circuit breaker state transitions
 * 
 * Requirement: 11.6
 */
export async function instrumentCircuitBreakerTransition<T>(
  service: string,
  fromState: string,
  toState: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'circuit_breaker.state_transition',
    async (span: Span) => {
      span.setAttribute('service', service);
      span.setAttribute('circuit_breaker.from_state', fromState);
      span.setAttribute('circuit_breaker.to_state', toState);
      
      return await fn();
    }
  );
}

/**
 * Instrument circuit breaker execution
 * 
 * Requirement: 11.6
 */
export async function instrumentCircuitBreakerExecution<T>(
  service: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'circuit_breaker.execute',
    async (span: Span) => {
      span.setAttribute('service', service);
      
      try {
        const result = await fn();
        span.setAttribute('circuit_breaker.result', 'success');
        return result;
      } catch (error) {
        span.setAttribute('circuit_breaker.result', 'failure');
        span.setAttribute('error.type', (error as Error).name);
        throw error;
      }
    }
  );
}

/**
 * Instrument connection pool operations
 * 
 * Requirement: 11.6
 */
export async function instrumentConnectionPoolOperation<T>(
  operation: string,
  userId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    `connection_pool.${operation}`,
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('connection_pool.operation', operation);
      
      return await fn();
    }
  );
}

/**
 * Instrument request queue operations
 * 
 * Requirement: 11.6
 */
export async function instrumentQueueOperation<T>(
  operation: string,
  userId: string,
  priority: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    `request_queue.${operation}`,
    async (span: Span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('request_queue.operation', operation);
      span.setAttribute('request_queue.priority', priority);
      
      return await fn();
    }
  );
}

/**
 * Add request context to current span
 * 
 * Requirement: 11.6
 */
export function addRequestContext(
  requestId: string,
  userId: string,
  endpoint: string,
  method: string
): void {
  addSpanAttributes({
    'request.id': requestId,
    'user.id': userId,
    'request.endpoint': endpoint,
    'request.method': method,
  });
}

/**
 * Add connection context to current span
 * 
 * Requirement: 11.6
 */
export function addConnectionContext(
  connectionId: string,
  userId: string,
  connectionType: string
): void {
  addSpanAttributes({
    'connection.id': connectionId,
    'user.id': userId,
    'connection.type': connectionType,
  });
}

/**
 * Record error in current span
 * 
 * Requirement: 11.6
 */
export function recordError(error: Error, context?: Record<string, string | number | boolean>): void {
  recordSpanException(error);
  
  if (context) {
    addSpanAttributes(context);
  }
}

/**
 * Add performance metrics to current span
 * 
 * Requirement: 11.6
 */
export function addPerformanceMetrics(
  latency: number,
  bytesReceived?: number,
  bytesSent?: number
): void {
  const attributes: Record<string, number> = {
    'performance.latency_ms': latency,
  };
  
  if (bytesReceived !== undefined) {
    attributes['performance.bytes_received'] = bytesReceived;
  }
  
  if (bytesSent !== undefined) {
    attributes['performance.bytes_sent'] = bytesSent;
  }
  
  addSpanAttributes(attributes);
}
