# Chisel Tunnel Integration Plan

## Overview

This document outlines the integration of Chisel as the third-party tunnel solution to replace the custom WebSocket tunnel implementation. Chisel provides a simpler, more reliable HTTP/WebSocket reverse proxy solution.

## Architecture

### Current Architecture (To Be Replaced)
```
[Web User] → [Cloud API] → [Custom WebSocket] → [SimpleTunnelClient] → [Local Ollama]
```

### New Architecture (Chisel)
```
[Web User] → [Cloud API] → [Chisel Server] → [Chisel Client] → [Local Ollama]
     ↑            ↑              ↑               ↑                ↑
  Browser    Node.js        Reverse        Desktop App    localhost:11434
                               Proxy        (Flutter)
```

## Phase 1: Server-Side Integration

### 1.1 Install Chisel Server

**Location**: `services/api-backend/`

**Steps**:
1. Add Chisel binary to Docker image or download on server
2. Create Chisel server wrapper/service
3. Configure Chisel with JWT authentication

**Files to Create**:
- `services/api-backend/tunnel/chisel-server.js` - Chisel server wrapper
- `services/api-backend/tunnel/chisel-integration.js` - Integration with Node.js API
- `config/chisel/chisel-server-config.json` - Chisel configuration

### 1.2 Chisel Server Setup

**Configuration**:
```javascript
// chisel-server.js
import { spawn } from 'child_process';
import path from 'path';

const CHISEL_BINARY = process.env.CHISEL_BINARY || '/usr/local/bin/chisel';

export class ChiselServer {
  constructor(logger, config) {
    this.logger = logger;
    this.config = config;
    this.process = null;
    this.port = config.port || 8080;
  }

  async start() {
    const args = [
      'server',
      '--port', this.port.toString(),
      '--reverse',
      '--auth', this.config.authToken, // JWT token for auth
      '--proxy', 'http://localhost:11434', // Default proxy target
    ];

    this.process = spawn(CHISEL_BINARY, args);
    
    this.process.stdout.on('data', (data) => {
      this.logger.info(`Chisel: ${data.toString()}`);
    });

    this.process.stderr.on('data', (data) => {
      this.logger.error(`Chisel error: ${data.toString()}`);
    });

    this.process.on('close', (code) => {
      this.logger.warn(`Chisel process exited with code ${code}`);
    });
  }

  async stop() {
    if (this.process) {
      this.process.kill();
      this.process = null;
    }
  }
}
```

### 1.3 Node.js Integration

**Replace**: `services/api-backend/tunnel/tunnel-proxy.js`

**New File**: `services/api-backend/tunnel/chisel-proxy.js`

```javascript
import http from 'http';
import { ChiselServer } from './chisel-server.js';

export class ChiselProxy {
  constructor(logger, config) {
    this.logger = logger;
    this.config = config;
    this.chiselServer = new ChiselServer(logger, config);
    this.userConnections = new Map(); // userId -> { port, client }
  }

  async start() {
    await this.chiselServer.start();
  }

  async forwardRequest(userId, httpRequest) {
    const connection = this.userConnections.get(userId);
    if (!connection) {
      throw new Error('Desktop client not connected');
    }

    // Forward request through Chisel tunnel
    return new Promise((resolve, reject) => {
      const options = {
        hostname: 'localhost',
        port: connection.port,
        path: httpRequest.path,
        method: httpRequest.method,
        headers: httpRequest.headers,
      };

      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => body += chunk);
        res.on('end', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: body,
          });
        });
      });

      req.on('error', reject);
      if (httpRequest.body) {
        req.write(httpRequest.body);
      }
      req.end();
    });
  }

  registerClient(userId, port) {
    this.userConnections.set(userId, { port, timestamp: new Date() });
    this.logger.info(`Chisel client registered for user ${userId} on port ${port}`);
  }

  unregisterClient(userId) {
    this.userConnections.delete(userId);
    this.logger.info(`Chisel client unregistered for user ${userId}`);
  }

  isUserConnected(userId) {
    return this.userConnections.has(userId);
  }
}
```

### 1.4 Update Server Routes

**Modify**: `services/api-backend/server.js`

**Changes**:
- Replace `TunnelProxy` with `ChiselProxy`
- Update tunnel routes to use Chisel
- Remove WebSocket server setup

## Phase 2: Client-Side Integration (Flutter)

### 2.1 Chisel Client Binary

**Options**:
1. Bundle Chisel binary with Flutter app
2. Download Chisel on first run
3. Use native plugin to execute Chisel

**Recommended**: Bundle binary for Windows/macOS/Linux

### 2.2 Create Chisel Client Service

**New File**: `lib/services/chisel_tunnel_client.dart`

```dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tunnel_config.dart';

class ChiselTunnelClient with ChangeNotifier {
  final TunnelConfig _config;
  Process? _chiselProcess;
  bool _isConnected = false;
  int? _tunnelPort;
  
  ChiselTunnelClient(this._config);

  bool get isConnected => _isConnected;
  int? get tunnelPort => _tunnelPort;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      // Find Chisel binary
      final chiselPath = await _getChiselPath();
      
      // Start Chisel client
      _chiselProcess = await Process.start(
        chiselPath,
        [
          'client',
          '${_config.cloudProxyUrl}:${_config.chiselPort}',
          'R:${_tunnelPort ?? 0}:localhost:11434',
          '--auth', _config.authToken,
        ],
        mode: ProcessStartMode.detached,
      );

      // Monitor process
      _chiselProcess!.exitCode.then((code) {
        debugPrint('[Chisel] Process exited with code $code');
        _handleDisconnection();
      });

      // Parse output to get assigned port
      _chiselProcess!.stdout
          .transform(utf8.decoder)
          .listen(_handleOutput);

      _isConnected = true;
      notifyListeners();
      
    } catch (e) {
      debugPrint('[Chisel] Connection failed: $e');
      _handleDisconnection();
      rethrow;
    }
  }

  void _handleOutput(String data) {
    debugPrint('[Chisel] $data');
    // Parse port from output if needed
    final portMatch = RegExp(r'port (\d+)').firstMatch(data);
    if (portMatch != null) {
      _tunnelPort = int.parse(portMatch.group(1)!);
      notifyListeners();
    }
  }

  Future<String> _getChiselPath() async {
    // Platform-specific path logic
    if (Platform.isWindows) {
      return 'assets/chisel/chisel-windows.exe';
    } else if (Platform.isMacOS) {
      return 'assets/chisel/chisel-darwin';
    } else {
      return 'assets/chisel/chisel-linux';
    }
  }

  void _handleDisconnection() {
    if (!_isConnected) return;
    _isConnected = false;
    _chiselProcess?.kill();
    _chiselProcess = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _chiselProcess?.kill();
    super.dispose();
  }
}
```

### 2.3 Update Tunnel Configuration Service

**Modify**: `lib/services/tunnel_configuration_service.dart`

**Changes**:
- Replace `SimpleTunnelClient` with `ChiselTunnelClient`
- Update connection logic
- Update status monitoring

### 2.4 Update UI Components

**Files to Update**:
- `lib/components/tunnel_status_indicator.dart`
- `lib/components/tunnel_management_panel.dart`
- `lib/screens/tunnel_settings_screen.dart`
- `lib/screens/unified_settings_screen.dart`

**Changes**: Update to use Chisel client instead of SimpleTunnelClient

## Phase 3: Authentication Integration

### 3.1 JWT Token Validation

**Chisel Authentication**:
- Chisel supports token-based authentication
- Pass JWT token to Chisel client
- Server validates token before allowing connection

**Implementation**:
```javascript
// Server-side validation
export function validateChiselToken(token) {
  // Validate JWT using AuthService
  const validationResult = await authService.validateToken(token);
  if (!validationResult.valid) {
    throw new Error('Invalid token');
  }
  return validationResult.payload.sub; // userId
}
```

## Phase 4: Migration Steps

### 4.1 Pre-Migration
1. ✅ Create Chisel integration plan
2. ✅ Identify all files to remove
3. ⏳ Create Chisel server integration
4. ⏳ Create Chisel client integration
5. ⏳ Update all references

### 4.2 Migration Execution
1. Deploy Chisel server alongside existing tunnel
2. Test Chisel integration in parallel
3. Migrate one user at a time (canary deployment)
4. Monitor for issues
5. Complete migration

### 4.3 Post-Migration
1. Remove old tunnel code
2. Update documentation
3. Clean up test files
4. Update deployment scripts

## Phase 5: Testing

### 5.1 Unit Tests
- Chisel server integration
- Chisel client connection
- JWT authentication
- Request forwarding

### 5.2 Integration Tests
- End-to-end tunnel flow
- Multiple concurrent users
- Connection failures
- Reconnection scenarios

### 5.3 Performance Tests
- Latency measurements
- Throughput testing
- Connection stability
- Memory usage

## Phase 6: Documentation Updates

### 6.1 Update Documentation
- `TUNNEL_IMPLEMENTATION_STATUS.md` → Replace with Chisel info
- `docs/ARCHITECTURE/SIMPLIFIED_TUNNEL_ARCHITECTURE.md` → Update
- `docs/DEVELOPMENT/SIMPLIFIED_TUNNEL_API.md` → Update
- Remove old tunnel documentation

### 6.2 Create New Documentation
- `docs/ARCHITECTURE/CHISEL_TUNNEL_ARCHITECTURE.md`
- `docs/DEVELOPMENT/CHISEL_INTEGRATION.md`
- `docs/OPERATIONS/CHISEL_TROUBLESHOOTING.md`

## Rollback Plan

If issues occur:
1. Keep old tunnel code available (tagged in git)
2. Feature flag to switch between implementations
3. Quick rollback procedure documented
4. Monitoring alerts for tunnel failures

## Timeline Estimate

- **Phase 1 (Server)**: 1-2 days
- **Phase 2 (Client)**: 2-3 days
- **Phase 3 (Auth)**: 0.5 days
- **Phase 4 (Migration)**: 1 day
- **Phase 5 (Testing)**: 2 days
- **Phase 6 (Docs)**: 1 day

**Total**: ~8-10 days

