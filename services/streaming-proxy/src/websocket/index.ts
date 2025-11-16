/**
 * WebSocket Module
 * Exports WebSocket handler implementation and related components
 */

export { WebSocketHandlerImpl } from './websocket-handler-impl';
export { WebSocketHandler, HealthStatus } from '../interfaces/websocket-handler';
export { HeartbeatManager, HeartbeatStats } from './heartbeat-manager';
export { CompressionManager } from './compression-manager';
export { FrameSizeValidator, ValidationResult } from './frame-size-validator';
export { GracefulCloseManager, CloseCode } from './graceful-close-manager';
