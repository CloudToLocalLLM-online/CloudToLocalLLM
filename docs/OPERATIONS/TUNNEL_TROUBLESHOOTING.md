# Simplified Tunnel System Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting steps for the Simplified Tunnel System, covering common issues, diagnostic procedures, and resolution strategies. The simplified tunnel system uses a single WebSocket connection and standard HTTP proxy patterns to connect cloud interfaces with local Ollama instances.

## Quick Diagnostic Checklist

Before diving into specific issues, run through this quick checklist:

- [ ] Desktop client is running and shows "Connected" status
- [ ] Local Ollama is running on `localhost:11434`
- [ ] Internet connection is stable
- [ ] JWT token is valid and not expired
- [ ] No firewall blocking WebSocket connections
- [ ] System time is synchronized

## Common Issues and Solutions

### 1. Desktop Client Connection Issues

#### 1.1 "Connection Failed" Error

**Symptoms:**
- Desktop client shows "Connection Failed" status
- Error messages about WebSocket connection failures
- Cannot establish initial connection to cloud

**Diagnostic Steps:**
```bash
# Test WebSocket endpoint accessibility
curl -I https://api.cloudtolocalllm.online/ws/tunnel

# Check DNS resolution
nslookup api.cloudtolocalllm.online

# Test basic connectivity
ping api.cloudtolocalllm.online

# Check if port 443 is accessible
telnet api.cloudtolocalllm.online 443
```

**Common Causes & Solutions:**

**Network/Firewall Issues:**
```bash
# Check firewall rules (Linux)
sudo ufw status
sudo iptables -L

# Check Windows Firewall
netsh advfirewall show allprofiles

# Test with firewall temporarily disabled
sudo ufw disable  # Linux
# Disable Windows Defender Firewall temporarily
```

**Corporate Proxy/Network:**
```bash
# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY

# Test with proxy bypass
export NO_PROXY="api.cloudtolocalllm.online"
```

**SSL Certificate Issues:**
```bash
# Check SSL certificate
openssl s_client -connect api.cloudtolocalllm.online:443 -servername api.cloudtolocalllm.online

# Update system certificates (Linux)
sudo apt update && sudo apt install ca-certificates
sudo update-ca-certificates

# Windows: Update certificates via Windows Update
```

#### 1.2 "Authentication Failed" Error

**Symptoms:**
- Connection attempts result in 401/403 errors
- "Invalid token" messages in logs
- Desktop client cannot authenticate

**Diagnostic Steps:**
```bash
# Check token validity (decode JWT)
# Use online JWT decoder or:
echo "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..." | base64 -d

# Test token with API
curl -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/health
```

**Solutions:**

**Expired Token:**
1. Log out and log back in to desktop client
2. Check system time synchronization
3. Verify Auth0 token expiration settings

**Invalid Token Format:**
1. Clear application data/cache
2. Reinstall desktop client if persistent
3. Check Auth0 application configuration

**Network Time Issues:**
```bash
# Sync system time (Linux)
sudo ntpdate -s time.nist.gov
sudo timedatectl set-ntp true

# Windows: Sync time
w32tm /resync
```

#### 1.3 Frequent Disconnections

**Symptoms:**
- Connection drops every few minutes
- Constant reconnection attempts
- Unstable tunnel status

**Diagnostic Steps:**
```bash
# Monitor connection stability
ping -c 100 api.cloudtolocalllm.online

# Check network interface stability
ip link show  # Linux
ipconfig /all  # Windows

# Monitor system resources
top  # Linux
taskmgr  # Windows
```

**Solutions:**

**Network Instability:**
1. Switch to wired connection if using WiFi
2. Update network drivers
3. Check router/modem stability
4. Contact ISP if persistent

**Power Management:**
```bash
# Disable USB power management (Linux)
echo 'on' | sudo tee /sys/bus/usb/devices/*/power/control

# Disable network adapter power saving (Windows)
# Device Manager → Network Adapters → Properties → Power Management
```

**System Resources:**
1. Close unnecessary applications
2. Increase virtual memory/swap
3. Check for memory leaks in desktop client

### 2. Request Timeout Issues

#### 2.1 "504 Gateway Timeout" Errors

**Symptoms:**
- Web requests timeout after 30 seconds
- "Gateway timeout" error messages
- Slow or unresponsive local Ollama

**Diagnostic Steps:**
```bash
# Test local Ollama directly
curl -X GET http://localhost:11434/api/tags

# Check Ollama performance
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama2","prompt":"test","stream":false}'

# Monitor system resources during requests
htop  # Linux
perfmon  # Windows
```

**Solutions:**

**Ollama Performance Issues:**
```bash
# Restart Ollama service
sudo systemctl restart ollama  # Linux
# Or restart Ollama application on Windows

# Check Ollama logs
journalctl -u ollama -f  # Linux
# Check Ollama application logs on Windows

# Optimize Ollama settings
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1
```

**System Resource Constraints:**
1. Close other applications using GPU/CPU
2. Increase system RAM if possible
3. Use smaller/faster models for testing
4. Check disk space and I/O performance

**Model Loading Issues:**
```bash
# Pre-load models to avoid loading delays
ollama run llama2 "test"

# Check available models
ollama list

# Pull missing models
ollama pull llama2
```

#### 2.2 Slow Response Times

**Symptoms:**
- Requests take longer than expected
- High latency in chat responses
- Performance degradation over time

**Diagnostic Steps:**
```bash
# Test network latency
ping api.cloudtolocalllm.online

# Test local Ollama response time
time curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama2","prompt":"Hello","stream":false}'

# Check tunnel metrics
curl -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/metrics
```

**Solutions:**

**Network Optimization:**
1. Use wired connection instead of WiFi
2. Close bandwidth-heavy applications
3. Check for network congestion
4. Consider upgrading internet plan

**Local Optimization:**
```bash
# Optimize Ollama for performance
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_ORIGINS="*"

# Use GPU acceleration if available
nvidia-smi  # Check GPU availability
export CUDA_VISIBLE_DEVICES=0
```

**Model Selection:**
1. Use smaller models for faster responses
2. Consider quantized models
3. Pre-load frequently used models

### 3. Authentication and Authorization Issues

#### 3.1 "403 Forbidden" Errors

**Symptoms:**
- Cannot access tunnel endpoints
- "Access denied" messages
- Cross-user access errors

**Diagnostic Steps:**
```bash
# Verify user ID in token
# Decode JWT token and check 'sub' field

# Test with correct user ID
curl -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/auth0|correct-user-id/api/tags

# Check Auth0 user profile
# Login to Auth0 dashboard and verify user details
```

**Solutions:**

**User ID Mismatch:**
1. Ensure using correct user ID in API calls
2. Check Auth0 user profile for correct ID format
3. Re-authenticate if user ID changed

**Token Permissions:**
1. Verify Auth0 application scopes
2. Check token audience and issuer
3. Ensure token has required permissions

#### 3.2 Rate Limiting Issues

**Symptoms:**
- "429 Too Many Requests" errors
- Requests blocked after high usage
- Rate limit headers in responses

**Diagnostic Steps:**
```bash
# Check rate limit headers
curl -I -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/health

# Look for headers:
# X-RateLimit-Limit: 1000
# X-RateLimit-Remaining: 0
# X-RateLimit-Reset: 1640995200
```

**Solutions:**

**Immediate Relief:**
1. Wait for rate limit window to reset
2. Reduce request frequency
3. Implement request queuing in applications

**Long-term Solutions:**
1. Optimize application to make fewer requests
2. Implement caching where appropriate
3. Contact support for rate limit increases if needed

### 4. Local Ollama Issues

#### 4.1 "503 Service Unavailable" Errors

**Symptoms:**
- Desktop client connected but requests fail
- "Local Ollama not accessible" errors
- Connection to localhost:11434 fails

**Diagnostic Steps:**
```bash
# Check if Ollama is running
ps aux | grep ollama  # Linux
tasklist | findstr ollama  # Windows

# Test Ollama API directly
curl http://localhost:11434/api/tags

# Check Ollama service status
sudo systemctl status ollama  # Linux
```

**Solutions:**

**Ollama Not Running:**
```bash
# Start Ollama service (Linux)
sudo systemctl start ollama
sudo systemctl enable ollama

# Start Ollama application (Windows)
# Run Ollama from Start Menu or desktop shortcut
```

**Port Conflicts:**
```bash
# Check what's using port 11434
sudo netstat -tlnp | grep 11434  # Linux
netstat -an | findstr 11434  # Windows

# Kill conflicting processes if necessary
sudo kill -9 <pid>
```

**Firewall Blocking Local Connections:**
```bash
# Allow local connections (Linux)
sudo ufw allow from 127.0.0.1 to any port 11434

# Windows: Add firewall exception for Ollama
```

#### 4.2 Model Loading Failures

**Symptoms:**
- Models not available in Ollama
- "Model not found" errors
- Slow model loading

**Diagnostic Steps:**
```bash
# List available models
ollama list

# Check model status
ollama show llama2

# Check disk space
df -h  # Linux
dir C:\ # Windows
```

**Solutions:**

**Missing Models:**
```bash
# Pull required models
ollama pull llama2
ollama pull codellama

# Verify model installation
ollama list
```

**Disk Space Issues:**
1. Free up disk space
2. Move Ollama models to larger drive
3. Use smaller models if space constrained

**Corrupted Models:**
```bash
# Remove and re-pull corrupted models
ollama rm llama2
ollama pull llama2
```

### 5. Performance and Monitoring

#### 5.1 High Memory Usage

**Symptoms:**
- System becomes slow or unresponsive
- Out of memory errors
- Desktop client crashes

**Diagnostic Steps:**
```bash
# Monitor memory usage
free -h  # Linux
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory  # Windows

# Check process memory usage
ps aux --sort=-%mem | head  # Linux
tasklist /fo table | sort /r /+5  # Windows
```

**Solutions:**

**Ollama Memory Optimization:**
```bash
# Limit concurrent models
export OLLAMA_MAX_LOADED_MODELS=1

# Use smaller models
ollama pull llama2:7b-chat-q4_0  # Quantized version
```

**System Optimization:**
1. Close unnecessary applications
2. Increase virtual memory/swap
3. Consider upgrading RAM

#### 5.2 Connection Pool Issues

**Symptoms:**
- Degraded performance over time
- Connection errors after extended use
- Memory leaks in desktop client

**Diagnostic Steps:**
```bash
# Check tunnel metrics
curl -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/metrics

# Monitor desktop client logs
# Check application logs for connection pool warnings
```

**Solutions:**

**Desktop Client Restart:**
1. Restart desktop client periodically
2. Monitor for memory leaks
3. Update to latest version

**Connection Management:**
1. Implement connection pooling limits
2. Clean up stale connections
3. Monitor connection health

## Advanced Diagnostics

### Log Analysis

#### Desktop Client Logs

**Linux:**
```bash
# Application logs location
~/.local/share/cloudtolocalllm/logs/

# View recent logs
tail -f ~/.local/share/cloudtolocalllm/logs/app.log

# Search for errors
grep -i error ~/.local/share/cloudtolocalllm/logs/app.log
```

**Windows:**
```cmd
# Application logs location
%APPDATA%\CloudToLocalLLM\logs\

# View logs
type "%APPDATA%\CloudToLocalLLM\logs\app.log"
```

#### Cloud API Logs

```bash
# Docker container logs
docker-compose logs -f api-backend

# Search for tunnel-related errors
docker-compose logs api-backend | grep -i tunnel

# Monitor real-time logs
docker-compose logs -f --tail=100 api-backend
```

### Network Analysis

#### Packet Capture

```bash
# Capture WebSocket traffic (Linux)
sudo tcpdump -i any -w tunnel-capture.pcap host api.cloudtolocalllm.online

# Analyze with Wireshark
wireshark tunnel-capture.pcap
```

#### Connection Testing

```bash
# Test WebSocket connection with wscat
npm install -g wscat
wscat -c "wss://api.cloudtolocalllm.online/ws/tunnel?token=<jwt_token>"

# Test HTTP proxy endpoints
curl -v -H "Authorization: Bearer <token>" \
     https://api.cloudtolocalllm.online/api/tunnel/<user_id>/api/tags
```

### Performance Profiling

#### System Performance

```bash
# Monitor system performance (Linux)
iostat -x 1
vmstat 1
sar -u 1

# Windows performance monitoring
perfmon
typeperf "\Processor(_Total)\% Processor Time" -si 1
```

#### Application Performance

```bash
# Profile desktop client (if debugging symbols available)
gdb cloudtolocalllm
perf record -g ./cloudtolocalllm

# Monitor API backend performance
docker stats api-backend
```

## Emergency Procedures

### Complete System Reset

If all else fails, perform a complete system reset:

1. **Stop all services:**
   ```bash
   # Stop desktop client
   pkill cloudtolocalllm  # Linux
   # Close from system tray on Windows
   
   # Stop Ollama
   sudo systemctl stop ollama  # Linux
   # Close Ollama application on Windows
   ```

2. **Clear application data:**
   ```bash
   # Linux
   rm -rf ~/.local/share/cloudtolocalllm/
   rm -rf ~/.config/cloudtolocalllm/
   
   # Windows
   rmdir /s "%APPDATA%\CloudToLocalLLM"
   rmdir /s "%LOCALAPPDATA%\CloudToLocalLLM"
   ```

3. **Restart services:**
   ```bash
   # Start Ollama
   sudo systemctl start ollama  # Linux
   # Start Ollama application on Windows
   
   # Start desktop client
   ./cloudtolocalllm  # Linux
   # Start from Start Menu on Windows
   ```

4. **Re-authenticate:**
   - Log in again through desktop client
   - Verify connection status
   - Test basic functionality

### Rollback Procedures

If issues persist after updates:

1. **Revert to previous version:**
   ```bash
   # Download previous version
   wget https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.10.2/cloudtolocalllm-linux.AppImage
   
   # Replace current version
   chmod +x cloudtolocalllm-linux.AppImage
   ./cloudtolocalllm-linux.AppImage
   ```

2. **Report issues:**
   - Collect logs and error messages
   - Document reproduction steps
   - Submit issue on GitHub repository

## Getting Help

### Self-Service Resources

1. **Documentation:**
   - [API Documentation](../DEVELOPMENT/SIMPLIFIED_TUNNEL_API.md)
   - [Deployment Guide](../DEPLOYMENT/SIMPLIFIED_TUNNEL_DEPLOYMENT.md)
   - [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)

2. **Community:**
   - GitHub Issues: Report bugs and feature requests
   - GitHub Discussions: Community support and questions

### Support Escalation

**Level 1 - Self-Service:**
- Follow this troubleshooting guide
- Check documentation and FAQ
- Search existing GitHub issues

**Level 2 - Community Support:**
- Post in GitHub Discussions
- Create detailed issue report
- Provide logs and system information

**Level 3 - Developer Support:**
- Critical system failures
- Security vulnerabilities
- Data loss scenarios

### Issue Reporting Template

When reporting issues, include:

```
**Environment:**
- OS: [Linux/Windows version]
- Desktop Client Version: [version]
- Ollama Version: [version]
- Browser: [if web-related]

**Issue Description:**
[Clear description of the problem]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Logs:**
[Relevant log entries]

**Additional Context:**
[Any other relevant information]
```

## Prevention and Best Practices

### Regular Maintenance

1. **Keep software updated:**
   - Update desktop client regularly
   - Keep Ollama updated
   - Update system packages

2. **Monitor system health:**
   - Check disk space regularly
   - Monitor memory usage
   - Review logs periodically

3. **Backup configurations:**
   - Export important settings
   - Document custom configurations
   - Keep installation files

### Performance Optimization

1. **System tuning:**
   - Optimize network settings
   - Configure appropriate swap/virtual memory
   - Use SSD for better I/O performance

2. **Application tuning:**
   - Configure appropriate model sizes
   - Optimize Ollama settings
   - Monitor resource usage

3. **Network optimization:**
   - Use wired connections when possible
   - Optimize router/firewall settings
   - Monitor bandwidth usage

This troubleshooting guide should help resolve most common issues with the Simplified Tunnel System. For issues not covered here, please refer to the support escalation procedures above.