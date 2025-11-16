import { AsyncLocalStorage } from 'async_hooks';
import { randomUUID } from 'crypto';

/**
 * Correlation context for request tracing
 * Stores correlation ID and other request-scoped data
 */
export interface CorrelationContext {
  correlationId: string;
  userId?: string;
  connectionId?: string;
  startTime: number;
}

/**
 * AsyncLocalStorage for correlation context
 * Automatically propagates context through async call chains
 */
const correlationStorage = new AsyncLocalStorage<CorrelationContext>();

/**
 * Initialize correlation context for a request
 * Generates a new correlation ID if not provided
 */
export function initializeCorrelationContext(
  correlationId?: string,
  userId?: string,
  connectionId?: string
): CorrelationContext {
  const context: CorrelationContext = {
    correlationId: correlationId || randomUUID(),
    userId,
    connectionId,
    startTime: Date.now(),
  };

  return context;
}

/**
 * Run a function within a correlation context
 * Automatically propagates context to all async operations
 */
export function runWithCorrelationContext<T>(
  context: CorrelationContext,
  fn: () => T
): T {
  return correlationStorage.run(context, fn);
}

/**
 * Run an async function within a correlation context
 */
export async function runWithCorrelationContextAsync<T>(
  context: CorrelationContext,
  fn: () => Promise<T>
): Promise<T> {
  return correlationStorage.run(context, fn);
}

/**
 * Get the current correlation context
 * Returns undefined if no context is active
 */
export function getCorrelationContext(): CorrelationContext | undefined {
  return correlationStorage.getStore();
}

/**
 * Get the current correlation ID
 * Returns undefined if no context is active
 */
export function getCorrelationId(): string | undefined {
  return correlationStorage.getStore()?.correlationId;
}

/**
 * Update correlation context with user ID
 */
export function setUserId(userId: string): void {
  const context = correlationStorage.getStore();
  if (context) {
    context.userId = userId;
  }
}

/**
 * Update correlation context with connection ID
 */
export function setConnectionId(connectionId: string): void {
  const context = correlationStorage.getStore();
  if (context) {
    context.connectionId = connectionId;
  }
}

/**
 * Get elapsed time since context was created (in milliseconds)
 */
export function getElapsedTime(): number {
  const context = correlationStorage.getStore();
  if (!context) return 0;
  return Date.now() - context.startTime;
}

/**
 * Express middleware to initialize correlation context for each request
 */
export function correlationMiddleware(
  req: any,
  res: any,
  next: any
): void {
  // Check for existing correlation ID in request headers
  const incomingCorrelationId = req.headers['x-correlation-id'] as string | undefined;

  // Initialize context
  const context = initializeCorrelationContext(incomingCorrelationId);

  // Run the rest of the request within this context
  runWithCorrelationContextAsync(context, async () => {
    // Add correlation ID to response headers
    res.setHeader('X-Correlation-ID', context.correlationId);

    // Continue to next middleware
    next();
  }).catch((error) => {
    console.error('Error in correlation middleware:', error);
    next(error);
  });
}
