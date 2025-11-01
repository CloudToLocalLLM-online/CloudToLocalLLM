# Tunnel System Redesign Plan

## Current State Analysis

### Current Implementation
- **Protocol**: WebSocket (WSS) with JSON message protocol
- **Client**: `SimpleTunnelClient` (Dart) - 181 lines
- **Server**: `TunnelProxy` (Node.js) - 390 lines
- **Message Protocol**: Custom JSON-based protocol
- **Authentication**: JWT tokens in query params

### Current Issues
1. Constant connection/disconnection loops
2. Connection closes immediately after establishing
3. Tray menu refreshes constantly due to connection state changes
4. Token validation issues on server side

## Research Findings

### VPN/Tunnel App Patterns
1. **WireGuard**: Uses UDP with persistent connections, keepalive pings
2. **OpenVPN**: TCP-based with control and data channels
3. **ngrok-style tunnels**: HTTP-based reverse proxy with persistent control channel
4. **frp (Fast Reverse Proxy)**: TCP/HTTP multiplexing, connection pooling

### Key Patterns to Adopt
1. **Control Channel + Data Channel**: Separate control from data
2. **Connection Heartbeat**: Proper keepalive mechanism
3. **Graceful Reconnection**: State preservation during reconnection
4. **Connection Pooling**: Multiple connections for load distribution
5. **Request Multiplexing**: Single connection for multiple requests

## Proposed New Architecture

### Option 1: Improved WebSocket Tunnel (Recommended)
- Keep WebSocket but fix connection stability
- Add proper heartbeat/keepalive
- Implement connection state machine
- Better error handling and recovery

### Option 2: HTTP/2 Multiplexed Tunnel
- Use HTTP/2 server push
- Native multiplexing
- Better connection reuse
- More complex to implement

### Option 3: gRPC-Web Tunnel
- Protocol buffers for efficiency
- Bidirectional streaming
- Type-safe communication
- Requires more infrastructure

## Recommended Approach: Improved WebSocket Tunnel

### Design Principles
1. **Connection Stability**: Proper state management, no false disconnections
2. **Heartbeat**: Server-initiated keepalive with timeout
3. **Request Queuing**: Queue requests during reconnection
4. **Graceful Degradation**: Fallback mechanisms for failures

### Implementation Steps
1. Redesign connection state machine
2. Implement proper heartbeat mechanism
3. Add request queuing for reconnections
4. Improve error handling and logging
5. Add connection metrics and monitoring

