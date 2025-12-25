# Git MCP Operations Monitoring and Troubleshooting Guide

## Overview

This guide provides comprehensive monitoring and troubleshooting procedures for MCP Git operations to ensure reliable and efficient operation.

## Monitoring Framework

### 1. Key Performance Indicators (KPIs)

#### 1.1 Operational Metrics
- **MCP Success Rate**: Percentage of operations that succeed with MCP
- **Fallback Rate**: Percentage of operations requiring GitHub CLI fallback
- **Operation Latency**: Time taken for MCP operations vs GitHub CLI
- **Error Rate**: Percentage of operations that fail completely

#### 1.2 System Health Metrics
- **MCP Server Uptime**: Availability of MCP GitHub server
- **GitHub API Rate Limit Usage**: Current rate limit consumption
- **Network Latency**: Response time to GitHub API
- **Authentication Status**: Validity of GitHub tokens

#### 1.3 Business Metrics
- **Workflow Completion Time**: End-to-end workflow duration
- **Team Productivity**: Time saved through MCP automation
- **Error Resolution Time**: Time to resolve MCP-related issues

### 2. Monitoring Implementation

#### 2.1 Automated Monitoring Script
```bash
#!/bin/bash
# monitor-mcp-operations.sh

# Configuration
LOG_FILE="/var/log/mcp_operations.log"
METRICS_FILE="/var/log/mcp_metrics.log"
ALERT_THRESHOLD_SUCCESS_RATE=95
ALERT_THRESHOLD_FALLBACK_RATE=5

# Function to log MCP operations
log_mcp_operation() {
    local operation=$1
    local status=$2
    local duration=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp | $operation | $status | ${duration}s" >> "$LOG_FILE"
}

# Function to collect metrics
collect_metrics() {
    local today=$(date '+%Y-%m-%d')
    
    # Calculate success rate
    local total_ops=$(grep "$today" "$LOG_FILE" | wc -l)
    local success_ops=$(grep "$today" "$LOG_FILE" | grep "SUCCESS" | wc -l)
    
    if [ $total_ops -gt 0 ]; then
        local success_rate=$((success_ops * 100 / total_ops))
        local fallback_rate=$(( (total_ops - success_ops) * 100 / total_ops ))
    else
        local success_rate=0
        local fallback_rate=0
    fi
    
    # Check GitHub API status
    local api_status=$(curl -s -o /dev/null -w "%{http_code}" https://api.github.com)
    
    # Log metrics
    echo "$today | Success Rate: $success_rate% | Fallback Rate: $fallback_rate% | API Status: $api_status" >> "$METRICS_FILE"
    
    # Check thresholds and alert
    check_alerts "$success_rate" "$fallback_rate" "$api_status"
}

# Function to check alert thresholds
check_alerts() {
    local success_rate=$1
    local fallback_rate=$2
    local api_status=$3
    
    # Check success rate
    if [ $success_rate -lt $ALERT_THRESHOLD_SUCCESS_RATE ]; then
        send_alert "CRITICAL" "MCP Success Rate below threshold: $success_rate% (threshold: $ALERT_THRESHOLD_SUCCESS_RATE%)"
    fi
    
    # Check fallback rate
    if [ $fallback_rate -gt $ALERT_THRESHOLD_FALLBACK_RATE ]; then
        send_alert "WARNING" "MCP Fallback Rate above threshold: $fallback_rate% (threshold: $ALERT_THRESHOLD_FALLBACK_RATE%)"
    fi
    
    # Check API status
    if [ "$api_status" != "200" ]; then
        send_alert "CRITICAL" "GitHub API Status: $api_status (expected: 200)"
    fi
}

# Function to send alerts
send_alert() {
    local severity=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "$timestamp | $severity | $message" >> "/var/log/mcp_alerts.log"
    
    # Send to monitoring system (example: Slack webhook)
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"[$severity] $message\"}" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null
    
    # Send email alert (example)
    echo "$message" | mail -s "[$severity] MCP Alert" admin@company.com
}

# Function to monitor MCP server health
monitor_mcp_server() {
    # Check if MCP server is running
    if ! systemctl is-active --quiet mcp-github-server; then
        send_alert "CRITICAL" "MCP GitHub server is not running"
        return 1
    fi
    
    # Check Docker container if using Docker
    if docker ps | grep -q "github-mcp-server"; then
        echo "✓ MCP Docker container is running"
    else
        send_alert "WARNING" "MCP Docker container is not running"
    fi
    
    return 0
}

# Function to monitor GitHub API rate limits
monitor_rate_limits() {
    local rate_limit_info=$(gh api rate_limit 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local remaining=$(echo "$rate_limit_info" | jq -r '.resources.core.remaining')
        local reset_time=$(echo "$rate_limit_info" | jq -r '.resources.core.reset')
        
        echo "Rate limit remaining: $remaining"
        
        if [ "$remaining" -lt 100 ]; then
            send_alert "WARNING" "GitHub API rate limit low: $remaining requests remaining"
        fi
    else
        send_alert "CRITICAL" "Cannot check GitHub API rate limits"
    fi
}

# Main monitoring loop
main() {
    echo "Starting MCP operations monitoring..."
    
    # Run monitoring checks
    monitor_mcp_server
    monitor_rate_limits
    collect_metrics
    
    echo "Monitoring check completed at $(date)"
}

# Run monitoring
main "$@"
```

#### 2.2 Real-time Dashboard
```bash
#!/bin/bash
# dashboard-mcp-operations.sh

# Function to display real-time dashboard
show_dashboard() {
    while true; do
        clear
        echo "=================================="
        echo "    MCP Operations Dashboard"
        echo "=================================="
        echo "Last Updated: $(date)"
        echo ""
        
        # Show MCP server status
        echo "MCP Server Status:"
        if systemctl is-active --quiet mcp-github-server; then
            echo "  ✓ Running"
        else
            echo "  ❌ Not Running"
        fi
        echo ""
        
        # Show recent operations
        echo "Recent Operations (Last 10):"
        tail -10 /var/log/mcp_operations.log | while read line; do
            echo "  $line"
        done
        echo ""
        
        # Show metrics
        echo "Today's Metrics:"
        tail -1 /var/log/mcp_metrics.log | while read line; do
            echo "  $line"
        done
        echo ""
        
        # Show alerts
        echo "Recent Alerts:"
        tail -5 /var/log/mcp_alerts.log | while read line; do
            echo "  $line"
        done
        echo ""
        
        sleep 30
    done
}

# Run dashboard
show_dashboard
```

### 3. Troubleshooting Procedures

#### 3.1 MCP Server Issues

**Issue**: MCP Server Not Responding
```bash
# Check server status
systemctl status mcp-github-server

# Check logs
journalctl -u mcp-github-server -f

# Restart server
systemctl restart mcp-github-server

# Verify restart
systemctl status mcp-github-server
```

**Issue**: Docker Container Issues
```bash
# Check container status
docker ps | grep github-mcp-server

# Check container logs
docker logs github-mcp-server

# Restart container
docker restart github-mcp-server

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

#### 3.2 Authentication Issues

**Issue**: GitHub Token Invalid
```bash
# Check current token
cat ~/.kilocode/mcp_settings.json | grep -A 5 '"github"'

# Test GitHub authentication
gh auth status

# Re-authenticate if needed
gh auth login

# Update MCP configuration with new token
# Edit ~/.kilocode/mcp_settings.json
```

**Issue**: Permission Denied
```bash
# Check token permissions
gh api user/keys

# Verify required scopes
gh api user | jq '.permissions'

# Regenerate token with required scopes
# Visit: https://github.com/settings/tokens
```

#### 3.3 Network Issues

**Issue**: Connection Timeout
```bash
# Test GitHub API connectivity
curl -s -o /dev/null -w "%{http_code}" https://api.github.com

# Check network connectivity
ping api.github.com

# Check DNS resolution
nslookup api.github.com

# Check firewall rules
sudo ufw status
```

**Issue**: High Latency
```bash
# Measure response time
time curl -s https://api.github.com

# Check network path
traceroute api.github.com

# Consider using VPN or alternative network
```

#### 3.4 Rate Limiting Issues

**Issue**: Rate Limit Exceeded
```bash
# Check current rate limit
gh api rate_limit

# Wait for rate limit reset
gh api rate_limit | jq '.resources.core.reset'

# Implement rate limiting in scripts
sleep 1  # Add delays between operations
```

**Issue**: High Rate Limit Usage
```bash
# Monitor rate limit usage
watch -n 60 'gh api rate_limit | jq ".resources.core.remaining"'

# Optimize operations to reduce API calls
# Batch operations where possible
# Cache results when appropriate
```

### 4. Diagnostic Tools

#### 4.1 MCP Operation Diagnostics
```bash
#!/bin/bash
# diagnose-mcp-operations.sh

# Function to diagnose MCP operations
diagnose_mcp_operations() {
    echo "=== MCP Operations Diagnostic ==="
    echo "Timestamp: $(date)"
    echo ""
    
    # Test basic MCP operation
    echo "Testing basic MCP operation..."
    if mcp--github--get_me 2>&1 | tee /tmp/mcp_test.log; then
        echo "✓ Basic MCP operation successful"
    else
        echo "❌ Basic MCP operation failed"
        echo "Error details:"
        cat /tmp/mcp_test.log
    fi
    echo ""
    
    # Test repository operation
    echo "Testing repository operation..."
    if mcp--github--list_branches {
        "owner": "organization",
        "repo": "repository"
    } 2>&1 | tee /tmp/mcp_repo_test.log; then
        echo "✓ Repository operation successful"
    else
        echo "❌ Repository operation failed"
        echo "Error details:"
        cat /tmp/mcp_repo_test.log
    fi
    echo ""
    
    # Check MCP server logs
    echo "Recent MCP server logs:"
    journalctl -u mcp-github-server --no-pager -n 20
    echo ""
    
    # Check system resources
    echo "System resources:"
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)"
    echo "Memory Usage:"
    free -h
    echo "Disk Usage:"
    df -h
    echo ""
}

# Run diagnostics
diagnose_mcp_operations
```

#### 4.2 Performance Analysis
```bash
#!/bin/bash
# analyze-mcp-performance.sh

# Function to analyze MCP performance
analyze_mcp_performance() {
    echo "=== MCP Performance Analysis ==="
    echo "Analysis Date: $(date)"
    echo ""
    
    # Analyze operation times from logs
    echo "Operation Time Analysis:"
    awk -F'|' '{print $4}' /var/log/mcp_operations.log | \
        awk '{sum+=$1; count++} END {if(count>0) print "Average time: " sum/count "s"; else print "No operations found"}'
    echo ""
    
    # Analyze success rates
    echo "Success Rate Analysis:"
    local total=$(wc -l < /var/log/mcp_operations.log)
    local success=$(grep "SUCCESS" /var/log/mcp_operations.log | wc -l)
    
    if [ $total -gt 0 ]; then
        local rate=$((success * 100 / total))
        echo "Success rate: $rate% ($success/$total)"
    else
        echo "No operations found"
    fi
    echo ""
    
    # Compare with GitHub CLI performance
    echo "GitHub CLI Performance Comparison:"
    echo "Testing GitHub CLI operation..."
    time gh api repos/organization/repository/branches > /dev/null
    echo ""
    
    echo "Testing MCP operation..."
    time mcp--github--list_branches {
        "owner": "organization",
        "repo": "repository"
    } > /dev/null 2>&1
    echo ""
}

# Run performance analysis
analyze_mcp_performance
```

### 5. Incident Response

#### 5.1 Incident Classification

**Severity Levels**:
- **Critical**: MCP server down, affecting all operations
- **High**: Authentication failures, affecting multiple users
- **Medium**: Performance degradation, affecting some operations
- **Low**: Individual operation failures, fallback working

#### 5.2 Incident Response Procedures

**Critical Incident Response**:
```bash
# 1. Immediate assessment
echo "CRITICAL: MCP server appears to be down"
systemctl status mcp-github-server

# 2. Attempt restart
systemctl restart mcp-github-server
sleep 5

# 3. Verify restart
systemctl status mcp-github-server

# 4. Test basic operation
if ! mcp--github--get_me 2>/dev/null; then
    echo "MCP server still not responding, escalate to infrastructure team"
    send_alert "CRITICAL" "MCP server restart failed"
fi

# 5. Activate fallback procedures
echo "Activating GitHub CLI fallback procedures"
```

**High Priority Incident Response**:
```bash
# 1. Identify scope
echo "HIGH: Authentication issues detected"
gh auth status

# 2. Check token validity
gh api user

# 3. Re-authenticate if needed
gh auth login

# 4. Update MCP configuration
# Edit ~/.kilocode/mcp_settings.json with new token

# 5. Test operations
mcp--github--get_me
```

#### 5.3 Escalation Procedures

**When to Escalate**:
- MCP server cannot be restarted
- Authentication issues persist after re-authentication
- Network issues affecting GitHub API access
- Performance issues not resolvable with current configuration

**Escalation Contacts**:
- **Infrastructure Team**: For server and network issues
- **Security Team**: For authentication and permission issues
- **DevOps Team**: For configuration and integration issues

### 6. Preventive Maintenance

#### 6.1 Regular Maintenance Tasks

**Daily Tasks**:
```bash
# Check MCP server status
systemctl status mcp-github-server

# Review operation logs
tail -100 /var/log/mcp_operations.log

# Check for alerts
tail -10 /var/log/mcp_alerts.log
```

**Weekly Tasks**:
```bash
# Review performance metrics
./analyze-mcp-performance.sh

# Check GitHub API rate limits
gh api rate_limit

# Update MCP configuration if needed
# Review and update ~/.kilocode/mcp_settings.json
```

**Monthly Tasks**:
```bash
# Review and rotate GitHub tokens
# Generate new token and update MCP configuration

# Update MCP server software
# Check for updates and apply as needed

# Review and optimize monitoring thresholds
# Adjust alert thresholds based on historical data
```

#### 6.2 Backup and Recovery

**Configuration Backup**:
```bash
# Backup MCP configuration
cp ~/.kilocode/mcp_settings.json ~/.kilocode/mcp_settings.json.backup.$(date +%Y%m%d)

# Backup monitoring scripts
tar -czf mcp-monitoring-backup-$(date +%Y%m%d).tar.gz monitor-mcp-operations.sh dashboard-mcp-operations.sh
```

**Recovery Procedures**:
```bash
# Restore MCP configuration
cp ~/.kilocode/mcp_settings.json.backup.$(date +%Y%m%d) ~/.kilocode/mcp_settings.json

# Restart MCP server
systemctl restart mcp-github-server

# Verify recovery
mcp--github--get_me
```

This comprehensive monitoring and troubleshooting guide ensures reliable operation of MCP Git tools and provides clear procedures for resolving issues quickly and efficiently.