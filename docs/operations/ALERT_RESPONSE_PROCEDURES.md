# Alert Response Procedures

This document provides procedures for responding to alerts from the CloudToLocalLLM tunnel system. Each alert includes what it means, how to investigate, and how to resolve it.

## Alert Overview

The tunnel system generates alerts in the following categories:
- **Critical**: Immediate action required, service is degraded or unavailable
- **Warning**: Potential issues that should be addressed soon

## Critical Alerts

### TunnelCircuitBreakerOpen

**What it means:**
The circuit breaker for the tunnel service has been open for more than 5 minutes. This indicates that the service is experiencing cascading failures and has stopped forwarding requests to prevent further damage.

**How to investigate:**
1. Check the streaming-proxy logs for errors:
   ```bash
   kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm
   ```
2. Look for patterns in the error messages (SSH connection failures, timeouts, etc.)
3. Check the metrics dashboard for error rate and latency:
   ```bash
   # Query Prometheus for error rate
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_errors_total[5m])'
   ```
4. Check if the local SSH server is reachable:
   ```bash
   # From streaming-proxy pod
   kubectl exec -it deployment/streaming-proxy -n cloudtolocalllm -- \
     ssh -v user@localhost -p 22
   ```

**How to resolve:**
1. **Identify the root cause:**
   - SSH server down: Restart the SSH server on the target machine
   - Network connectivity: Check firewall rules and network connectivity
   - SSH authentication: Verify SSH credentials and key permissions
   - Resource exhaustion: Check CPU and memory usage

2. **Fix the underlying issue:**
   - If SSH server is down, restart it
   - If network is down, restore connectivity
   - If authentication failed, update credentials
   - If resources exhausted, scale up the deployment

3. **Reset the circuit breaker:**
   ```bash
   # The circuit breaker will automatically reset after 60 seconds of no failures
   # Monitor the metrics to confirm recovery
   kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm | grep "circuit breaker"
   ```

4. **Verify recovery:**
   - Check that error rate drops below 5%
   - Verify that new connections are being accepted
   - Test a tunnel connection manually

---

### TunnelConnectionStorm

**What it means:**
More than 1000 new connections were established in the last minute. This could indicate:
- Legitimate traffic spike
- Client reconnection loop (clients reconnecting repeatedly)
- DDoS attack

**How to investigate:**
1. Check the connection rate in metrics:
   ```bash
   # Query Prometheus for connection rate
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_connections_total[1m])'
   ```

2. Check the source IPs of connections:
   ```bash
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep "new connection" | head -20
   ```

3. Check if clients are reconnecting repeatedly:
   ```bash
   # Look for reconnection patterns in logs
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep "reconnect"
   ```

4. Check for DDoS patterns:
   - Multiple connections from same IP
   - Connections that close immediately
   - Unusual user agents or headers

**How to resolve:**
1. **If legitimate traffic spike:**
   - Scale up the deployment:
     ```bash
     kubectl scale deployment streaming-proxy --replicas=5 -n cloudtolocalllm
     ```
   - Monitor metrics to ensure load is distributed

2. **If client reconnection loop:**
   - Check client logs for errors causing reconnections
   - Verify server is responding correctly to requests
   - Check for network issues between client and server
   - Restart affected clients if necessary

3. **If DDoS attack:**
   - Enable rate limiting at ingress level:
     ```bash
     # Update ingress annotations
     kubectl patch ingress ingress-nginx -n cloudtolocalllm -p \
       '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/limit-rps":"100"}}}'
     ```
   - Block suspicious IPs using firewall rules
   - Contact cloud provider for DDoS mitigation

---

### TunnelServiceUnavailable

**What it means:**
The streaming-proxy service is not responding to health checks. The service may be:
- Crashed or restarting
- Out of memory or CPU
- Stuck in a deadlock
- Network connectivity issue

**How to investigate:**
1. Check pod status:
   ```bash
   kubectl get pods -n cloudtolocalllm -l app=streaming-proxy
   kubectl describe pod <pod-name> -n cloudtolocalllm
   ```

2. Check pod logs:
   ```bash
   kubectl logs <pod-name> -n cloudtolocalllm --tail=100
   ```

3. Check resource usage:
   ```bash
   kubectl top pod <pod-name> -n cloudtolocalllm
   ```

4. Check if pod is in CrashLoopBackOff:
   ```bash
   kubectl get events -n cloudtolocalllm | grep streaming-proxy
   ```

**How to resolve:**
1. **If pod is crashing:**
   - Check logs for error messages
   - Fix the underlying issue (configuration, dependency, etc.)
   - Restart the pod:
     ```bash
     kubectl delete pod <pod-name> -n cloudtolocalllm
     ```

2. **If out of memory:**
   - Increase memory limits in deployment:
     ```bash
     kubectl set resources deployment streaming-proxy \
       --limits=memory=1Gi -n cloudtolocalllm
     ```
   - Investigate memory leak in application code

3. **If out of CPU:**
   - Increase CPU limits:
     ```bash
     kubectl set resources deployment streaming-proxy \
       --limits=cpu=1000m -n cloudtolocalllm
     ```
   - Scale up replicas to distribute load

4. **If network issue:**
   - Check network connectivity from pod:
     ```bash
     kubectl exec <pod-name> -n cloudtolocalllm -- ping 8.8.8.8
     ```
   - Check DNS resolution:
     ```bash
     kubectl exec <pod-name> -n cloudtolocalllm -- nslookup kubernetes.default
     ```

---

## Warning Alerts

### TunnelHighErrorRate

**What it means:**
The error rate has exceeded 5% for the last 5 minutes. This indicates that a significant portion of requests are failing.

**How to investigate:**
1. Check error types:
   ```bash
   # Query Prometheus for error breakdown
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_errors_total[5m]) by (error_type)'
   ```

2. Check logs for error patterns:
   ```bash
   kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm | grep ERROR
   ```

3. Check if specific users are affected:
   ```bash
   # Query Prometheus for errors by user
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_errors_total[5m]) by (user_id)'
   ```

4. Run diagnostics on affected clients:
   - Ask users to run tunnel diagnostics
   - Check client logs for connection issues

**How to resolve:**
1. **If authentication errors:**
   - Verify Supabase Auth configuration
   - Check JWT token validity
   - Restart API backend if needed

2. **If SSH errors:**
   - Check SSH server logs
   - Verify SSH credentials
   - Check SSH key permissions

3. **If network errors:**
   - Check network connectivity
   - Verify firewall rules
   - Check for packet loss

4. **If server errors:**
   - Check server logs for exceptions
   - Verify server configuration
   - Check resource availability

---

### TunnelHighLatency

**What it means:**
The 95th percentile latency has exceeded 200ms for the last 5 minutes. This indicates that requests are taking longer than expected.

**How to investigate:**
1. Check latency distribution:
   ```bash
   # Query Prometheus for latency percentiles
   curl 'http://prometheus:9090/api/v1/query?query=histogram_quantile(0.95, rate(tunnel_request_latency_ms_bucket[5m]))'
   ```

2. Check if latency is increasing:
   ```bash
   # Query for latency trend
   curl 'http://prometheus:9090/api/v1/query_range?query=histogram_quantile(0.95, rate(tunnel_request_latency_ms_bucket[5m]))&start=<1h-ago>&end=<now>&step=1m'
   ```

3. Check server resource usage:
   ```bash
   kubectl top nodes
   kubectl top pods -n cloudtolocalllm
   ```

4. Check network latency:
   ```bash
   # From streaming-proxy pod
   kubectl exec deployment/streaming-proxy -n cloudtolocalllm -- ping -c 10 <target-host>
   ```

**How to resolve:**
1. **If server is overloaded:**
   - Scale up replicas:
     ```bash
     kubectl scale deployment streaming-proxy --replicas=5 -n cloudtolocalllm
     ```
   - Increase resource limits

2. **If network latency:**
   - Check network conditions
   - Verify network path to target
   - Consider using CDN or regional deployment

3. **If SSH is slow:**
   - Check SSH server performance
   - Verify SSH key exchange algorithms
   - Check for SSH compression overhead

4. **If client is slow:**
   - Check client network conditions
   - Verify client resources
   - Ask user to run diagnostics

---

### TunnelQueueNearlyFull

**What it means:**
The request queue is more than 90% full for a user. This indicates that requests are being queued faster than they can be processed.

**How to investigate:**
1. Check queue size:
   ```bash
   # Query Prometheus for queue size
   curl 'http://prometheus:9090/api/v1/query?query=tunnel_queue_size'
   ```

2. Check request rate:
   ```bash
   # Query Prometheus for request rate
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_requests_total[1m])'
   ```

3. Check if requests are being processed:
   ```bash
   # Query Prometheus for success rate
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_requests_total{status="success"}[1m])'
   ```

4. Check user's connection status:
   ```bash
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep <user-id>
   ```

**How to resolve:**
1. **If processing is slow:**
   - Check server latency
   - Verify SSH connection is healthy
   - Check for circuit breaker being open

2. **If request rate is too high:**
   - Advise user to reduce request rate
   - Check if user is making duplicate requests
   - Verify rate limiting is working

3. **If queue is too small:**
   - Increase queue size in configuration:
     ```bash
     kubectl set env deployment/streaming-proxy \
       MAX_QUEUE_SIZE=500 -n cloudtolocalllm
     ```

4. **If connection is unstable:**
   - Check network connectivity
   - Verify client is not reconnecting repeatedly
   - Check for firewall issues

---

### TunnelHighActiveConnections

**What it means:**
More than 500 active tunnel connections are open. This could indicate:
- Legitimate high usage
- Clients not closing connections properly
- Connection leak

**How to investigate:**
1. Check connection count by user:
   ```bash
   # Query Prometheus for connections by user
   curl 'http://prometheus:9090/api/v1/query?query=tunnel_active_connections by (user_id)'
   ```

2. Check connection age:
   ```bash
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep "connection age"
   ```

3. Check for idle connections:
   ```bash
   # Look for connections that haven't sent data recently
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep "idle"
   ```

**How to resolve:**
1. **If legitimate high usage:**
   - Scale up deployment
   - Increase connection limits per user

2. **If clients not closing connections:**
   - Check client code for proper cleanup
   - Implement connection timeout
   - Restart affected clients

3. **If connection leak:**
   - Check for resource leaks in code
   - Implement connection cleanup
   - Restart service to clear leaked connections

---

### TunnelRateLimitViolations

**What it means:**
More than 10 rate limit violations occurred in the last 5 minutes. This indicates that users are exceeding their rate limits.

**How to investigate:**
1. Check which users are being rate limited:
   ```bash
   # Query Prometheus for violations by user
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_rate_limit_violations_total[5m]) by (user_id)'
   ```

2. Check their request rate:
   ```bash
   # Query Prometheus for request rate by user
   curl 'http://prometheus:9090/api/v1/query?query=rate(tunnel_requests_total[1m]) by (user_id)'
   ```

3. Check if they're on a higher tier:
   ```bash
   kubectl logs deployment/streaming-proxy -n cloudtolocalllm | grep <user-id>
   ```

**How to resolve:**
1. **If user needs higher limit:**
   - Upgrade user to higher tier
   - Update rate limit configuration for user

2. **If user is making duplicate requests:**
   - Contact user to optimize their usage
   - Implement request deduplication

3. **If legitimate spike:**
   - Temporarily increase rate limit
   - Monitor for abuse

---

## General Troubleshooting Steps

### 1. Check Service Health
```bash
# Check pod status
kubectl get pods -n cloudtolocalllm -l app=streaming-proxy

# Check service endpoints
kubectl get endpoints streaming-proxy -n cloudtolocalllm

# Check service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://streaming-proxy:3001/api/tunnel/health
```

### 2. Check Logs
```bash
# View recent logs
kubectl logs deployment/streaming-proxy -n cloudtolocalllm --tail=100

# Follow logs in real-time
kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm

# View logs from all replicas
kubectl logs -f deployment/streaming-proxy -n cloudtolocalllm --all-containers=true
```

### 3. Check Metrics
```bash
# Query Prometheus directly
kubectl port-forward svc/prometheus 9090:9090 -n cloudtolocalllm

# Then access http://localhost:9090 in browser
```

### 4. Check Configuration
```bash
# View ConfigMap
kubectl get configmap streaming-proxy-config -n cloudtolocalllm -o yaml

# View Secrets (values hidden)
kubectl get secret streaming-proxy-secrets -n cloudtolocalllm -o yaml
```

### 5. Restart Service
```bash
# Restart deployment
kubectl rollout restart deployment/streaming-proxy -n cloudtolocalllm

# Wait for rollout to complete
kubectl rollout status deployment/streaming-proxy -n cloudtolocalllm
```

### 6. Scale Deployment
```bash
# Scale up
kubectl scale deployment streaming-proxy --replicas=5 -n cloudtolocalllm

# Scale down
kubectl scale deployment streaming-proxy --replicas=2 -n cloudtolocalllm
```

---

## Escalation Procedures

### Level 1: Automatic Recovery
- Circuit breaker resets automatically after 60 seconds
- Pods restart automatically on crash
- Connections retry with exponential backoff

### Level 2: Manual Investigation
- Check logs and metrics
- Run diagnostics
- Identify root cause

### Level 3: Manual Intervention
- Restart service
- Scale up deployment
- Update configuration

### Level 4: Escalation
- Contact infrastructure team
- Check cloud provider status
- Review recent changes

---

## Prevention

### Best Practices
1. **Monitor metrics regularly** - Set up dashboards for key metrics
2. **Set up alerts** - Configure alerts for critical thresholds
3. **Test recovery** - Regularly test failure scenarios
4. **Document procedures** - Keep runbooks up to date
5. **Review logs** - Regularly review logs for patterns
6. **Capacity planning** - Monitor growth and plan for scaling

### Preventive Maintenance
1. **Regular updates** - Keep dependencies and OS updated
2. **Security patches** - Apply security patches promptly
3. **Performance tuning** - Optimize configuration based on metrics
4. **Backup and recovery** - Test backup and recovery procedures
5. **Disaster recovery** - Plan for major failures

---

## Contact Information

- **On-Call Team**: oncall@cloudtolocalllm.online
- **Slack Channel**: #tunnel-alerts
- **Documentation**: https://docs.cloudtolocalllm.online
- **Status Page**: https://status.cloudtolocalllm.online
