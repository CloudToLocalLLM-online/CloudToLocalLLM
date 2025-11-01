# Old Tunnel Implementation Cleanup Plan

## Overview

This document lists all files, references, and code that needs to be removed when migrating from the custom WebSocket tunnel to Chisel.

## Files to Delete

### Server-Side (Node.js)
- ✅ `services/api-backend/tunnel/tunnel-proxy.js` - Custom tunnel proxy
- ✅ `services/api-backend/tunnel/message-protocol.js` - Custom message protocol
- ✅ `services/api-backend/tunnel/tunnel-routes.js` - Tunnel HTTP routes (replace with Chisel routes)
- ✅ `services/api-backend/tunnel/tunnel-metrics.js` - Tunnel metrics (if Chisel has built-in)
- ✅ `services/api-backend/tunnel/connection-manager.js` - Connection manager (if not used elsewhere)
- ✅ `services/api-backend/websocket-server.js` - WebSocket server setup (replace with Chisel)

### Client-Side (Flutter/Dart)
- ✅ `lib/services/simple_tunnel_client.dart` - Old tunnel client
- ✅ `lib/services/tunnel_message_protocol.dart` - Message protocol (if not used by Chisel)
- ✅ `lib/models/tunnel_message.dart` - Message models (if not needed)
- ✅ `lib/utils/tunnel_logger.dart` - Tunnel logger (if not needed)

### Tests
- ✅ `test/integration/tunnel_communication_e2e_test.dart`
- ✅ `test/services/tunnel_configuration_service_test.dart` (update to test Chisel)
- ✅ `test/services/tunnel_message_protocol_test.dart`
- ✅ `test/services/tunnel_llm_request_handler_test.dart` (update to work with Chisel)
- ✅ `test/api-backend/tunnel-proxy.test.js`
- ✅ `test/api-backend/tunnel-routes.test.js`
- ✅ `test/api-backend/tunnel-integration.test.js`
- ✅ `test/api-backend/tunnel-proxy-performance.test.js`
- ✅ `test/api-backend/tunnel-load.test.js`
- ✅ `test/api-backend/tunnel-error-handling.test.js`
- ✅ `test/api-backend/tunnel-system-integration.test.js`
- ✅ `test/api-backend/tunnel/tunnel-server.test.js`
- ✅ `test/e2e/tunnel-auth-integration.spec.js`
- ✅ `test/e2e/tunnel-comprehensive-diagnosis.spec.js`
- ✅ `test/e2e/tunnel-performance-analysis.spec.js`
- ✅ `test/e2e/tunnel-ui-improvements.spec.js`
- ✅ `test/e2e/tunnel-verification.spec.js`

### Documentation (Update or Remove)
- ✅ `TUNNEL_IMPLEMENTATION_STATUS.md` - Update to reflect Chisel
- ✅ `TUNNEL_REDESIGN_PLAN.md` - Archive or delete
- ✅ `docs/ARCHITECTURE/SIMPLIFIED_TUNNEL_ARCHITECTURE.md` - Update to Chisel
- ✅ `docs/DEVELOPMENT/SIMPLIFIED_TUNNEL_API.md` - Update to Chisel API
- ✅ `docs/FIXES/TUNNEL_CLIENT_AUTH.md` - Archive (old fixes)
- ✅ `docs/OPERATIONS/TUNNEL_TROUBLESHOOTING.md` - Update for Chisel
- ✅ `docs/DEPLOYMENT/TUNNEL_ROLLBACK_PROCEDURES.md` - Update for Chisel
- ✅ `test/TUNNEL_TESTING_README.md` - Update for Chisel testing

## Code References to Update

### Server-Side Files to Update

1. **`services/api-backend/server.js`**
   - Remove: `setupWebSocketTunnel` import
   - Remove: WebSocket server initialization
   - Remove: `tunnelProxyWebSocket` references
   - Add: Chisel server initialization
   - Update: Tunnel routes to use Chisel

2. **`services/api-backend/routes/monitoring.js`**
   - Remove: Tunnel-specific metrics (if any)
   - Update: Health checks to use Chisel

### Client-Side Files to Update

1. **`lib/services/tunnel_configuration_service.dart`**
   - Remove: `SimpleTunnelClient` import
   - Remove: All `SimpleTunnelClient` references
   - Add: `ChiselTunnelClient` integration

2. **`lib/services/connection_manager_service.dart`**
   - Update: Tunnel connection status to use Chisel
   - Remove: Old tunnel client references

3. **`lib/services/native_tray_service.dart`**
   - Update: Tunnel status display (if any tunnel-specific logic)

4. **`lib/services/tunnel_llm_request_handler.dart`**
   - Update: To work with Chisel (if needed)
   - Check: If message protocol changes affect this

5. **`lib/main.dart`**
   - Remove: `SimpleTunnelClient` provider (if exists)
   - Add: `ChiselTunnelClient` provider

### UI Components to Update

1. **`lib/components/tunnel_status_indicator.dart`**
   - Update: Status display for Chisel

2. **`lib/components/tunnel_management_panel.dart`**
   - Update: Connection management for Chisel

3. **`lib/components/tunnel_connection_wizard.dart`**
   - Update: Setup flow for Chisel

4. **`lib/components/tunnel_setup_banner.dart`**
   - Update: Status checks for Chisel

5. **`lib/screens/tunnel_settings_screen.dart`**
   - Update: Settings UI for Chisel

6. **`lib/screens/tunnel_status_screen.dart`**
   - Update: Status display for Chisel

7. **`lib/screens/unified_settings_screen.dart`**
   - Update: Tunnel test button and status

## Models to Keep/Update

### Keep (Still Needed)
- ✅ `lib/models/tunnel_config.dart` - Configuration model (may need updates)
- ✅ `lib/models/tunnel_validation_result.dart` - Validation result model

### Remove (Not Needed with Chisel)
- ⚠️ `lib/models/tunnel_message.dart` - Custom message protocol (Chisel uses HTTP)

## Dependencies to Remove

### pubspec.yaml
- Check: `web_socket_channel` - May not be needed if Chisel uses native sockets
- Keep: Other dependencies

### package.json
- Check: `ws` package - May not be needed
- Check: Any tunnel-specific packages

## Configuration Files to Update

1. **`config/nginx/production.conf`**
   - Remove: WebSocket proxy settings (if Chisel handles differently)
   - Update: Chisel proxy configuration

2. **`docker-compose.production.yml`**
   - Update: Tunnel service to use Chisel
   - Remove: Old tunnel container (if separate)

3. **`config/app_config.dart`**
   - Update: Tunnel URLs for Chisel
   - Remove: Old WebSocket URLs

## Import Statements to Clean

Search for and remove:
- `import.*simple_tunnel_client`
- `import.*tunnel_proxy`
- `import.*websocket-server`
- `import.*message-protocol`
- `from.*tunnel-proxy`
- `from.*websocket-server`

## Global Search and Replace

### Patterns to Find and Update:
1. `SimpleTunnelClient` → `ChiselTunnelClient`
2. `TunnelProxy` → `ChiselProxy`
3. `tunnel-proxy.js` → `chisel-proxy.js`
4. `websocket-server.js` → `chisel-server.js`
5. `simple_tunnel_client.dart` → `chisel_tunnel_client.dart`

## Testing Cleanup

- Remove all old tunnel tests
- Create new Chisel integration tests
- Update test utilities

## Documentation Cleanup

- Archive old tunnel docs (don't delete, move to `/docs/archive/`)
- Create new Chisel documentation
- Update README and main docs

## Execution Order

1. ✅ Create cleanup plan (this document)
2. ⏳ Backup current tunnel code (git tag)
3. ⏳ Remove test files
4. ⏳ Remove old implementation files
5. ⏳ Update all references
6. ⏳ Remove unused imports
7. ⏳ Update documentation
8. ⏳ Clean up dependencies
9. ⏳ Verify no broken references

## Verification Checklist

After cleanup:
- [ ] No references to `SimpleTunnelClient` remain
- [ ] No references to `TunnelProxy` remain
- [ ] No imports of old tunnel files
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Dependencies cleaned up
- [ ] Git commit with cleanup

