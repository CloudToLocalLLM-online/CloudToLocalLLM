# CloudToLocalLLM Tunnel Functionality Test Plan

## Architecture Analysis Summary

Based on my analysis, the tunnel system is a complex SSH-over-WebSocket architecture with the following key components:

### Frontend Components (Flutter)
- **TunnelService** (`lib/services/tunnel_service.dart`): Main service managing tunnel lifecycle
- **SSHTunnelClient** (`lib/services/ssh/ssh_tunnel_client.dart`): Handles SSH connection over WebSocket
- **TunnelConfigManager** (`lib/services/tunnel/tunnel_config_manager.dart`): Manages tunnel configurations
- **ConnectionManagerService** (`lib/services/connection_manager_service.dart`): Coordinates local and tunnel connections
- **Tunnel UI Components**: Various widgets for displaying tunnel status and metrics

### Backend Components (Node.js)
- **SSHProxy** (`services/api-backend/tunnel/ssh-proxy.js`): Core SSH tunnel server
- **TunnelRoutes** (`services/api-backend/tunnel/tunnel-routes.js`): API endpoints for tunnel management
- **TunnelHealthService** (`services/api-backend/services/tunnel-health-service.js`): Health monitoring
- **TunnelFailoverService** (`services/api-backend/services/tunnel-failover-service.js`): Failover logic
- **TunnelUsageService** (`services/api-backend/services/tunnel-usage-service.js`): Usage tracking
- **TunnelWebhookService** (`services/api-backend/services/tunnel-webhook-service.js`): Webhook integration

### Tunnel Flow
1. **Connection Establishment**: Desktop client connects via WebSocket to SSH server
2. **Authentication**: JWT token used as SSH password for authentication
3. **Reverse Tunneling**: SSH client establishes reverse port forwarding
4. **Registration**: Client registers tunnel with server via REST API
5. **Request Forwarding**: HTTP requests forwarded through SSH tunnel
6. **Health Monitoring**: Periodic health checks and metrics collection

## Test Environment Setup

### Prerequisites
- Flutter development environment with desktop support
- Node.js backend with SSH2 module
- PostgreSQL database for tunnel metadata
- Valid JWT authentication tokens
- Local Ollama instance running on port 11434

### Configuration
- **Frontend**: Update `lib/config/app_config.dart` to point to local backend
- **Backend**: Configure `services/api-backend/config.js` with local tunnel settings
- **Database**: Ensure tunnel tables are properly migrated

## Test Scenarios

### 1. Tunnel Connection Tests
**Objective**: Verify basic tunnel connection functionality

**Test Cases**:
- [ ] Test successful tunnel connection with valid credentials
- [ ] Test connection failure with invalid credentials
- [ ] Test connection recovery after network interruption
- [ ] Test multiple concurrent tunnel connections
- [ ] Test tunnel connection timeout handling

**Expected Results**:
- Successful connections establish SSH session and register with server
- Failed connections show appropriate error messages
- Reconnection attempts follow exponential backoff pattern
- Multiple connections are properly isolated

### 2. Tunnel Registration and Management
**Objective**: Test tunnel registration lifecycle

**Test Cases**:
- [ ] Test tunnel registration with valid tunnel ID
- [ ] Test duplicate tunnel registration handling
- [ ] Test tunnel unregistration
- [ ] Test tunnel cleanup on disconnection
- [ ] Test tunnel port assignment and conflict resolution

**Expected Results**:
- Registration creates proper server-side tunnel mapping
- Duplicate registrations are handled gracefully
- Unregistration properly cleans up resources
- Port assignment avoids conflicts

### 3. Request Forwarding
**Objective**: Test HTTP request forwarding through tunnel

**Test Cases**:
- [ ] Test successful request forwarding
- [ ] Test request forwarding with large payloads
- [ ] Test concurrent request handling
- [ ] Test request timeout handling
- [ ] Test request error propagation

**Expected Results**:
- Requests are properly forwarded through SSH tunnel
- Large payloads are handled without data corruption
- Concurrent requests are processed in order
- Timeouts are handled gracefully
- Errors are properly propagated to client

### 4. Health Monitoring and Metrics
**Objective**: Test tunnel health monitoring

**Test Cases**:
- [ ] Test periodic health check functionality
- [ ] Test health check failure detection
- [ ] Test metrics collection and aggregation
- [ ] Test health status API endpoints
- [ ] Test connection quality calculation

**Expected Results**:
- Health checks run at configured intervals
- Failed health checks trigger appropriate actions
- Metrics are accurately collected and stored
- API endpoints return current health status
- Connection quality reflects actual performance

### 5. Error Handling and Recovery
**Objective**: Test tunnel error scenarios

**Test Cases**:
- [ ] Test SSH connection failures
- [ ] Test WebSocket disconnections
- [ ] Test server-side tunnel failures
- [ ] Test client-side tunnel failures
- [ ] Test automatic recovery mechanisms

**Expected Results**:
- Errors are properly logged and categorized
- Recovery mechanisms attempt to restore connectivity
- Failed connections are properly cleaned up
- User-facing error messages are informative

### 6. Failover Functionality
**Objective**: Test tunnel failover capabilities

**Test Cases**:
- [ ] Test primary endpoint failure detection
- [ ] Test automatic failover to secondary endpoint
- [ ] Test manual failover triggering
- [ ] Test failover recovery and fallback
- [ ] Test failover metrics and logging

**Expected Results**:
- Primary endpoint failures are detected quickly
- Failover to secondary endpoints is seamless
- Manual failover works as expected
- Recovery restores primary endpoint usage
- Failover events are properly logged

### 7. Webhook Integration
**Objective**: Test tunnel webhook functionality

**Test Cases**:
- [ ] Test webhook registration
- [ ] Test webhook event triggering
- [ ] Test webhook delivery and retry logic
- [ ] Test webhook security and validation
- [ ] Test webhook error handling

**Expected Results**:
- Webhooks are properly registered and stored
- Tunnel events trigger appropriate webhook calls
- Delivery attempts follow retry logic
- Webhook payloads are properly validated
- Failed deliveries are handled gracefully

### 8. Usage Tracking and Billing
**Objective**: Test tunnel usage tracking

**Test Cases**:
- [ ] Test usage event recording
- [ ] Test usage metrics aggregation
- [ ] Test usage reporting APIs
- [ ] Test usage-based rate limiting
- [ ] Test usage data persistence

**Expected Results**:
- Usage events are accurately recorded
- Metrics are properly aggregated by time periods
- API endpoints return correct usage data
- Rate limiting is applied based on usage
- Usage data persists across server restarts

## Monitoring and Logging Setup

### Logging Configuration
- **Frontend**: Enable verbose logging in `lib/config/app_config.dart`
- **Backend**: Configure Winston logger with tunnel-specific settings
- **Database**: Enable query logging for tunnel operations

### Monitoring Tools
- **Frontend**: Use Flutter DevTools for widget inspection
- **Backend**: Use Node.js inspector for debugging
- **Network**: Use Wireshark/Charles Proxy for traffic analysis
- **Performance**: Use Chrome DevTools for WebSocket monitoring

### Log Analysis
- Monitor SSH connection logs for authentication issues
- Track WebSocket traffic for connection stability
- Analyze HTTP request/response cycles
- Review database operations for tunnel metadata

## Test Execution Plan

### Phase 1: Environment Setup
1. Configure local development environment
2. Set up tunnel configuration files
3. Initialize database with test data
4. Configure logging and monitoring tools

### Phase 2: Basic Functionality Testing
1. Test tunnel connection establishment
2. Test tunnel registration and unregistration
3. Test basic request forwarding
4. Test health monitoring functionality

### Phase 3: Advanced Functionality Testing
1. Test error handling and recovery
2. Test failover mechanisms
3. Test webhook integration
4. Test usage tracking

### Phase 4: Performance and Stress Testing
1. Test concurrent tunnel connections
2. Test high-volume request forwarding
3. Test long-running tunnel sessions
4. Test resource cleanup under load

### Phase 5: Security Testing
1. Test authentication and authorization
2. Test input validation
3. Test rate limiting
4. Test data encryption

## Expected Issues and Remediation

### Common Issues
1. **Connection Stability**: WebSocket connections may drop unexpectedly
2. **Authentication Failures**: JWT token validation may fail
3. **Port Conflicts**: Tunnel port assignment may have conflicts
4. **Resource Leaks**: Connections may not be properly cleaned up
5. **Performance Bottlenecks**: High-volume traffic may cause slowdowns

### Remediation Strategies
1. Implement robust reconnection logic
2. Enhance error messages for authentication failures
3. Add port conflict detection and resolution
4. Implement comprehensive resource cleanup
5. Add load balancing and request throttling

## Success Criteria

### Minimum Viable Test
- Basic tunnel connection works reliably
- Request forwarding functions correctly
- Health monitoring provides accurate status
- Error handling prevents crashes

### Optimal Test Results
- All test scenarios pass consistently
- Performance meets expected benchmarks
- Resource usage remains within limits
- Error rates are minimal
- Recovery mechanisms work reliably

## Next Steps

1. Set up local development environment
2. Configure tunnel services for testing
3. Implement test automation where possible
4. Execute test scenarios systematically
5. Document findings and create remediation plan