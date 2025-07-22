# Simplified Tunnel System Deployment Guide - On-Demand Architecture

## Overview

This guide covers the deployment process for the new Simplified Tunnel System, which replaces the complex multi-layered tunnel architecture with a streamlined design. The deployment involves updating both cloud infrastructure and desktop client applications.

## 🏗️ On-Demand Tunnel Architecture

**Important**: The Simplified Tunnel System uses an **on-demand architecture** where tunnels are created only when users first log in, not during deployment.

### Key Architectural Principles

1. **Tunnel Creation on User Login**: Tunnels are established when users authenticate and connect their desktop clients
2. **Zero Active Tunnels During Deployment**: A successful deployment will have zero active tunnels, which is expected and healthy
3. **Tunnel Creation System Ready**: Deployment verification checks that the tunnel creation infrastructure is ready, not that tunnels are active
4. **User-Triggered Tunnel Lifecycle**: Tunnels are created, maintained, and destroyed based on user activity

### Deployment vs. Runtime Behavior

| Phase | Expected Tunnel State | Verification Criteria |
|-------|----------------------|----------------------|
| **Deployment** | Zero active tunnels | Tunnel creation system ready |
| **User Login** | Tunnel created on-demand | WebSocket connection established |
| **User Activity** | Tunnel maintained | Requests proxied successfully |
| **User Logout** | Tunnel destroyed | Connection cleaned up |

### Verification Endpoints

- **Deployment Health**: `/api/tunnel/health` - Checks tunnel creation capability (no auth required)
- **User Tunnel Status**: `/api/tunnel/status` - Checks user's specific tunnel (auth required)
- **User Tunnel Health**: `/api/tunnel/health/:userId` - Checks specific user tunnel (auth required)

## Pre-Deployment Checklist

### Infrastructure Requirements
- [ ] Node.js 18+ on cloud servers
- [ ] WebSocket support enabled in load balancer/proxy
- [ ] Auth0 configuration updated with new scopes
- [ ] SSL certificates valid for WebSocket connections
- [ ] Monitoring and logging systems configured

### Testing Requirements
- [ ] All unit tests passing
- [ ] Integration tests completed
- [ ] Load testing completed with 100+ concurrent users
- [ ] Security testing completed
- [ ] Performance benchmarks meet requirements

### Backup Requirements
- [ ] Current system backed up
- [ ] Database backup completed
- [ ] Configuration files backed up
- [ ] Rollback procedures tested

## Deployment Strategy

### Phase 1: Infrastructure Preparation (30 minutes)

#### 1.1 Update Cloud Infrastructure

**Update API Backend:**
```bash
# Navigate to project directory
cd /path/to/CloudToLocalLLM

# Pull latest changes
git pull origin main

# Install dependencies
cd api-backend
npm install

# Run tests
npm test

# Build if necessary
npm run build
```

**Update Environment Variables:**
```bash
# Add to .env or environment configuration
TUNNEL_WEBSOCKET_PATH=/ws/tunnel
TUNNEL_REQUEST_TIMEOUT=30000
TUNNEL_PING_INTERVAL=30000
TUNNEL_MAX_CONNECTIONS_PER_USER=5
TUNNEL_RATE_LIMIT_WINDOW=900000
TUNNEL_RATE_LIMIT_MAX_REQUESTS=1000
```

**Update Nginx Configuration:**
```nginx
# Add WebSocket support for tunnel endpoint
location /ws/tunnel {
    proxy_pass http://api-backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
}

# Update tunnel proxy endpoints
location ~ ^/api/tunnel/([^/]+)/(.*)$ {
    proxy_pass http://api-backend/api/tunnel/$1/$2;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 35;
    proxy_send_timeout 35;
}
```

#### 1.2 Deploy Updated API Backend

**Using Docker Compose:**
```bash
# Build new images
docker-compose build api-backend

# Deploy with zero-downtime
docker-compose up -d --no-deps api-backend

# Verify deployment
docker-compose ps
docker-compose logs api-backend
```

**Using Direct Deployment:**
```bash
# Stop current service
sudo systemctl stop cloudtolocalllm-api

# Update code
git pull origin main
cd api-backend
npm install

# Start service
sudo systemctl start cloudtolocalllm-api
sudo systemctl status cloudtolocalllm-api
```

#### 1.3 Verify Infrastructure

**Health Check:**
```bash
# Test tunnel health endpoint
curl -X GET https://api.cloudtolocalllm.online/api/tunnel/health

# Expected response:
# {
#   "status": "healthy",
#   "checks": {
#     "hasConnections": false,
#     "successRateOk": true,
#     "timeoutRateOk": true,
#     "averageResponseTimeOk": true
#   }
# }
```

**WebSocket Test:**
```bash
# Test WebSocket endpoint (requires valid JWT)
wscat -c "wss://api.cloudtolocalllm.online/ws/tunnel?token=<jwt_token>"
```

### Phase 2: Desktop Client Deployment (45 minutes)

#### 2.1 Build Updated Desktop Clients

**Linux Build:**
```bash
# Build AppImage
./scripts/packaging/build_appimage.sh

# Build DEB package
./scripts/packaging/build_deb.sh

# Verify builds
ls -la dist/
```

**Windows Build:**
```bash
# Build Windows executable
flutter build windows --release

# Create installer (if using)
./scripts/powershell/Create-UnifiedPackages.ps1
```

#### 2.2 Test Desktop Client

**Pre-deployment Testing:**
```bash
# Run desktop client tests
flutter test

# Run integration tests
flutter test integration_test/

# Manual testing checklist:
# [ ] Client connects to new WebSocket endpoint
# [ ] Authentication works with JWT tokens
# [ ] HTTP requests are forwarded correctly
# [ ] Reconnection works after network interruption
# [ ] Performance is acceptable
```

#### 2.3 Deploy Desktop Clients

**Gradual Rollout Strategy:**
1. Deploy to internal testing users (5%)
2. Deploy to beta users (20%)
3. Deploy to all users (100%)

**Distribution Methods:**
- Update existing installations via auto-update mechanism
- Provide download links for manual updates
- Use package managers where available (AUR, etc.)

### Phase 3: Container Integration Update (15 minutes)

#### 3.1 Update Container Configuration

**Environment Variables:**
```bash
# Update container environment
export OLLAMA_BASE_URL="https://api.cloudtolocalllm.online/api/tunnel/${USER_ID}"

# Verify containers can reach new endpoint
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     "${OLLAMA_BASE_URL}/api/tags"
```

#### 3.2 Test Container Integration

**Integration Test:**
```bash
# Run container integration tests
./scripts/test-container-tunnel-integration.js

# Verify container configuration
./scripts/verify-container-config.js
```

### Phase 4: Monitoring and Validation (30 minutes)

#### 4.1 Enable Monitoring

**Metrics Collection:**
```bash
# Verify metrics endpoints
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     https://api.cloudtolocalllm.online/api/tunnel/metrics

# Set up monitoring alerts
# - Connection count drops below threshold
# - Success rate drops below 95%
# - Response time exceeds 5 seconds
# - Error rate exceeds 5%
```

**Log Monitoring:**
```bash
# Monitor tunnel logs
tail -f /var/log/cloudtolocalllm/tunnel.log

# Monitor API backend logs
docker-compose logs -f api-backend
```

#### 4.2 Performance Validation

**Load Testing:**
```bash
# Run load tests with new tunnel system
./scripts/run-tunnel-verification-test.sh

# Expected results:
# - 100+ concurrent connections supported
# - <500ms average response time
# - >99% success rate
# - <1% timeout rate
```

**User Acceptance Testing:**
- [ ] Web interface works correctly
- [ ] Desktop client connects successfully
- [ ] Chat responses are received promptly
- [ ] No data leakage between users
- [ ] Error handling works as expected

## Rollback Procedures

### Emergency Rollback (if critical issues detected)

#### Step 1: Revert API Backend
```bash
# Using Docker Compose
docker-compose down api-backend
git checkout <previous_commit>
docker-compose build api-backend
docker-compose up -d api-backend

# Using Direct Deployment
sudo systemctl stop cloudtolocalllm-api
git checkout <previous_commit>
cd api-backend && npm install
sudo systemctl start cloudtolocalllm-api
```

#### Step 2: Revert Nginx Configuration
```bash
# Restore previous nginx configuration
sudo cp /etc/nginx/sites-available/cloudtolocalllm.backup \
       /etc/nginx/sites-available/cloudtolocalllm
sudo nginx -t
sudo systemctl reload nginx
```

#### Step 3: Notify Users
```bash
# Send notification to users about rollback
# Provide instructions for reverting desktop client if needed
```

### Partial Rollback (for specific issues)

#### Desktop Client Issues
- Provide previous version download links
- Update auto-update mechanism to serve previous version
- Communicate issue and timeline for fix

#### Container Integration Issues
- Revert container environment variables
- Update container configurations to use legacy endpoints
- Test container functionality

## Post-Deployment Tasks

### Immediate (within 1 hour)
- [ ] Monitor system metrics for anomalies
- [ ] Check error logs for unexpected issues
- [ ] Verify user connections are working
- [ ] Confirm performance metrics meet targets

### Short-term (within 24 hours)
- [ ] Analyze performance data
- [ ] Review user feedback
- [ ] Monitor resource usage
- [ ] Update documentation if needed

### Long-term (within 1 week)
- [ ] Remove legacy tunnel code
- [ ] Clean up unused dependencies
- [ ] Update monitoring dashboards
- [ ] Conduct post-deployment review

## Troubleshooting Common Issues

### WebSocket Connection Failures

**Symptoms:**
- Desktop clients cannot connect
- "Connection failed" errors in logs

**Diagnosis:**
```bash
# Check WebSocket endpoint
curl -I https://api.cloudtolocalllm.online/ws/tunnel

# Check nginx configuration
sudo nginx -t
sudo systemctl status nginx

# Check API backend logs
docker-compose logs api-backend | grep -i websocket
```

**Resolution:**
1. Verify nginx WebSocket configuration
2. Check firewall rules for WebSocket traffic
3. Validate SSL certificate for WebSocket connections
4. Restart nginx and API backend services

### Authentication Issues

**Symptoms:**
- 401/403 errors on tunnel endpoints
- JWT validation failures

**Diagnosis:**
```bash
# Test JWT token validation
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     https://api.cloudtolocalllm.online/api/tunnel/health

# Check Auth0 configuration
# Verify JWKS endpoint accessibility
curl https://${AUTH0_DOMAIN}/.well-known/jwks.json
```

**Resolution:**
1. Verify Auth0 domain and audience configuration
2. Check JWT token expiration
3. Validate JWKS endpoint accessibility
4. Review Auth0 application settings

### Performance Issues

**Symptoms:**
- High response times
- Timeout errors
- Poor user experience

**Diagnosis:**
```bash
# Check system resources
top
df -h
free -m

# Monitor tunnel metrics
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     https://api.cloudtolocalllm.online/api/tunnel/metrics

# Check connection counts
netstat -an | grep :443 | wc -l
```

**Resolution:**
1. Scale API backend instances if needed
2. Optimize database queries
3. Increase timeout values if appropriate
4. Review and optimize tunnel proxy code

### Container Integration Issues

**Symptoms:**
- Containers cannot reach local Ollama
- 503 Service Unavailable errors

**Diagnosis:**
```bash
# Test container connectivity
docker exec <container_id> curl ${OLLAMA_BASE_URL}/api/tags

# Check environment variables
docker exec <container_id> env | grep OLLAMA

# Verify tunnel proxy routing
curl -H "Authorization: Bearer ${JWT_TOKEN}" \
     https://api.cloudtolocalllm.online/api/tunnel/${USER_ID}/api/tags
```

**Resolution:**
1. Verify OLLAMA_BASE_URL environment variable
2. Check JWT token in container environment
3. Validate tunnel proxy routing
4. Test desktop client connection

## Security Considerations

### During Deployment
- [ ] Validate all SSL certificates
- [ ] Verify JWT token validation is working
- [ ] Test user isolation
- [ ] Check rate limiting functionality
- [ ] Validate CORS configuration

### Post-Deployment
- [ ] Monitor for unusual authentication patterns
- [ ] Review access logs for anomalies
- [ ] Verify no cross-user data leakage
- [ ] Test security headers are present
- [ ] Validate WebSocket origin checking

## Performance Benchmarks

### Expected Metrics
- **Connection Time:** <2 seconds for initial connection
- **Response Time:** <500ms average for API requests
- **Success Rate:** >99% for all requests
- **Timeout Rate:** <1% of all requests
- **Concurrent Users:** Support 100+ simultaneous connections
- **Memory Usage:** <100MB per 50 concurrent connections

### Monitoring Thresholds
- **Alert if:** Success rate drops below 95%
- **Alert if:** Average response time exceeds 2 seconds
- **Alert if:** Timeout rate exceeds 5%
- **Alert if:** Connection count drops unexpectedly
- **Alert if:** Memory usage exceeds 200MB per instance

## Support and Escalation

### Level 1 Support
- Check system status dashboard
- Review common troubleshooting steps
- Verify user configuration

### Level 2 Support
- Access system logs and metrics
- Perform advanced diagnostics
- Coordinate with development team

### Level 3 Support (Development Team)
- Code-level debugging
- Infrastructure changes
- Emergency rollback decisions

### Contact Information
- **Operations Team:** ops@cloudtolocalllm.online
- **Development Team:** dev@cloudtolocalllm.online
- **Emergency Escalation:** +1-XXX-XXX-XXXX

## Success Criteria

### Technical Success
- [ ] All automated tests passing
- [ ] Performance metrics within acceptable ranges
- [ ] No critical errors in logs
- [ ] User connections stable
- [ ] Container integration working

### Business Success
- [ ] User satisfaction maintained or improved
- [ ] System reliability improved
- [ ] Maintenance overhead reduced
- [ ] Development velocity increased
- [ ] Infrastructure costs optimized

## Conclusion

The Simplified Tunnel System deployment represents a significant architectural improvement that reduces complexity while maintaining functionality and security. Following this deployment guide ensures a smooth transition with minimal user impact and maximum system reliability.

For questions or issues during deployment, refer to the troubleshooting section or contact the appropriate support team based on the escalation procedures outlined above.