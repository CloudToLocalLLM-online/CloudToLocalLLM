/**
 * OpenTelemetry Tracer Configuration
 * 
 * Configures distributed tracing for the streaming proxy server.
 * Exports traces to Jaeger or console based on configuration.
 * 
 * Requirements: 11.6
 */

import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { ConsoleSpanExporter } from '@opentelemetry/sdk-trace-node';
import { BatchSpanProcessor, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-node';
import { trace, Span, SpanStatusCode, context } from '@opentelemetry/api';

// Configuration
const SERVICE_NAME = 'streaming-proxy';
const JAEGER_ENDPOINT = process.env.OTEL_EXPORTER_JAEGER_ENDPOINT;
const ENABLE_TRACING = process.env.ENABLE_TRACING !== 'false'; // Enabled by default
const ENVIRONMENT = process.env.NODE_ENV || 'development';

/**
 * Initialize OpenTelemetry SDK
 */
export function initializeTracing(): NodeSDK | null {
  if (!ENABLE_TRACING) {
    console.log('OpenTelemetry tracing is disabled');
    return null;
  }

  // Create SDK with service information
  // Resource attributes are set via environment variables or SDK configuration

  // Configure span exporter
  let spanProcessor;
  if (JAEGER_ENDPOINT) {
    // Export to Jaeger in production using OTLP HTTP exporter
    const jaegerExporter = new OTLPTraceExporter({
      url: JAEGER_ENDPOINT,
    });
    spanProcessor = new BatchSpanProcessor(jaegerExporter);
    console.log(`OpenTelemetry tracing enabled with OTLP Jaeger exporter: ${JAEGER_ENDPOINT}`);
  } else {
    // Export to console in development
    const consoleExporter = new ConsoleSpanExporter();
    spanProcessor = new SimpleSpanProcessor(consoleExporter);
    console.log('OpenTelemetry tracing enabled with console exporter');
  }

  // Create and configure SDK
  const sdk = new NodeSDK({
    spanProcessor,
    instrumentations: [
      getNodeAutoInstrumentations({
        // Disable some instrumentations if needed
        '@opentelemetry/instrumentation-fs': {
          enabled: false, // File system operations can be noisy
        },
      }),
    ],
  });

  // Start the SDK
  try {
    sdk.start();
    console.log('OpenTelemetry SDK started successfully');
  } catch (error) {
    console.error('Error starting OpenTelemetry SDK:', error);
    return null;
  }

  // Graceful shutdown
  process.on('SIGTERM', () => {
    sdk
      .shutdown()
      .then(() => console.log('OpenTelemetry SDK shut down successfully'))
      .catch((error) => console.error('Error shutting down OpenTelemetry SDK:', error))
      .finally(() => process.exit(0));
  });

  return sdk;
}

/**
 * Get the tracer instance
 */
export function getTracer() {
  return trace.getTracer(SERVICE_NAME);
}

/**
 * Create a span for an operation
 * 
 * @param name - Span name
 * @param fn - Function to execute within the span
 * @param attributes - Optional span attributes
 * @returns Result of the function
 */
export async function withSpan<T>(
  name: string,
  fn: (span: Span) => Promise<T>,
  attributes?: Record<string, string | number | boolean>
): Promise<T> {
  const tracer = getTracer();
  
  return tracer.startActiveSpan(name, async(span) => {
    try {
      // Add attributes if provided
      if (attributes) {
        for (const [key, value] of Object.entries(attributes)) {
          span.setAttribute(key, value);
        }
      }

      // Execute function
      const result = await fn(span);

      // Mark span as successful
      span.setStatus({ code: SpanStatusCode.OK });
      
      return result;
    } catch (error) {
      // Record error
      span.recordException(error as Error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: (error as Error).message,
      });
      
      throw error;
    } finally {
      // End span
      span.end();
    }
  });
}

/**
 * Add attributes to the current span
 */
export function addSpanAttributes(attributes: Record<string, string | number | boolean>): void {
  const span = trace.getActiveSpan();
  if (span) {
    for (const [key, value] of Object.entries(attributes)) {
      span.setAttribute(key, value);
    }
  }
}

/**
 * Add an event to the current span
 */
export function addSpanEvent(name: string, attributes?: Record<string, string | number | boolean>): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.addEvent(name, attributes);
  }
}

/**
 * Record an exception in the current span
 */
export function recordSpanException(error: Error): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.recordException(error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
  }
}

/**
 * Instrument WebSocket connection
 */
export async function traceWebSocketConnection<T>(
  userId: string,
  connectionId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'websocket.connection',
    async(span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('connection.id', connectionId);
      span.setAttribute('connection.type', 'websocket');
      
      return await fn();
    }
  );
}

/**
 * Instrument request forwarding
 */
export async function traceRequestForward<T>(
  userId: string,
  requestId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'tunnel.forward_request',
    async(span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('request.id', requestId);
      
      const startTime = Date.now();
      const result = await fn();
      const latency = Date.now() - startTime;
      
      span.setAttribute('request.latency_ms', latency);
      
      return result;
    }
  );
}

/**
 * Instrument SSH operations
 */
export async function traceSSHOperation<T>(
  operation: string,
  userId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    `ssh.${operation}`,
    async(span) => {
      span.setAttribute('user.id', userId);
      span.setAttribute('ssh.operation', operation);
      
      return await fn();
    }
  );
}

/**
 * Instrument authentication
 */
export async function traceAuthentication<T>(
  userId: string | undefined,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'auth.validate_token',
    async(span) => {
      if (userId) {
        span.setAttribute('user.id', userId);
      }
      
      return await fn();
    }
  );
}

/**
 * Instrument rate limiting
 */
export async function traceRateLimitCheck<T>(
  userId: string,
  fn: () => Promise<T>
): Promise<T> {
  return withSpan(
    'rate_limit.check',
    async(span) => {
      span.setAttribute('user.id', userId);
      
      return await fn();
    }
  );
}

