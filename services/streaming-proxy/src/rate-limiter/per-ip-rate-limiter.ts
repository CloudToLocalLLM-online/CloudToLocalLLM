/**
 * Per-IP Rate Limiter
 * 
 * Implements DDoS protection by rate limiting requests per IP address.
 * Tracks suspicious IPs and provides blocking capabilities.
 * 
 * Requirements: 4.10
 */

import { TokenBucketRateLimiter } from './token-bucket-rate-limiter';
import { RateLimitConfig } from '../interfaces/auth-middleware';
import { RateLimitResult } from '../interfaces/rate-limiter';

/**
 * Default IP rate limit (more restrictive than user limits)
 */
export const DEFAULT_IP_LIMIT: RateLimitConfig = {
  requestsPerMinute: 200,
  maxConcurrentConnections: 5,
  maxQueueSize: 100,
};

/**
 * Aggressive limit for suspicious IPs
 */
export const SUSPICIOUS_IP_LIMIT: RateLimitConfig = {
  requestsPerMinute: 10,
  maxConcurrentConnections: 1,
  maxQueueSize: 10,
};

export interface IpInfo {
  ip: string;
  requestCount: number;
  violationCount: number;
  firstSeen: Date;
  lastSeen: Date;
  blocked: boolean;
  suspicious: boolean;
}

export interface DDoSDetectionResult {
  isDDoS: boolean;
  suspiciousIps: string[];
  totalRequests: number;
  uniqueIps: number;
  reason?: string;
}

export class PerIpRateLimiter {
  private rateLimiter: TokenBucketRateLimiter;
  private ipInfo: Map<string, IpInfo> = new Map();
  private blockedIps: Set<string> = new Set();
  private suspiciousIps: Set<string> = new Set();
  private readonly violationThreshold = 5; // violations before marking suspicious
  private readonly blockThreshold = 10; // violations before blocking

  constructor(defaultLimit?: RateLimitConfig) {
    const globalLimit = defaultLimit || DEFAULT_IP_LIMIT;
    this.rateLimiter = new TokenBucketRateLimiter(globalLimit);
  }

  /**
   * Check if IP is within rate limit
   * Tracks requests per IP address
   */
  async checkIpLimit(ip: string, userId?: string): Promise<RateLimitResult> {
    // Check if IP is blocked
    if (this.isBlocked(ip)) {
      return {
        allowed: false,
        remaining: 0,
        resetAt: new Date(Date.now() + 3600000), // 1 hour
        retryAfter: 3600,
      };
    }

    // Update IP info
    this.updateIpInfo(ip);

    // Use stricter limits for suspicious IPs
    if (this.isSuspicious(ip)) {
      this.rateLimiter.setUserLimit(ip, SUSPICIOUS_IP_LIMIT);
    }

    // Check limit
    const dummyUserId = userId || `ip_${ip}`;
    return await this.rateLimiter.checkLimit(dummyUserId, ip);
  }

  /**
   * Record a request from an IP
   */
  recordIpRequest(ip: string, userId?: string): void {
    const dummyUserId = userId || `ip_${ip}`;
    this.rateLimiter.recordRequest(dummyUserId, ip);
    
    const info = this.ipInfo.get(ip);
    if (info) {
      info.requestCount++;
      info.lastSeen = new Date();
    }
  }

  /**
   * Block a specific IP address
   */
  blockIp(ip: string, reason?: string): void {
    this.blockedIps.add(ip);
    
    const info = this.ipInfo.get(ip);
    if (info) {
      info.blocked = true;
    }

    this.logSecurityEvent('ip_blocked', ip, reason);
  }

  /**
   * Unblock an IP address
   */
  unblockIp(ip: string): void {
    this.blockedIps.delete(ip);
    
    const info = this.ipInfo.get(ip);
    if (info) {
      info.blocked = false;
    }

    this.logSecurityEvent('ip_unblocked', ip);
  }

  /**
   * Check if IP is blocked
   */
  isBlocked(ip: string): boolean {
    return this.blockedIps.has(ip);
  }

  /**
   * Mark IP as suspicious
   */
  markSuspicious(ip: string, reason?: string): void {
    this.suspiciousIps.add(ip);
    
    const info = this.ipInfo.get(ip);
    if (info) {
      info.suspicious = true;
    }

    this.logSecurityEvent('ip_suspicious', ip, reason);
  }

  /**
   * Check if IP is suspicious
   */
  isSuspicious(ip: string): boolean {
    return this.suspiciousIps.has(ip);
  }

  /**
   * Get IP information
   */
  getIpInfo(ip: string): IpInfo | undefined {
    return this.ipInfo.get(ip);
  }

  /**
   * Get all blocked IPs
   */
  getBlockedIps(): string[] {
    return Array.from(this.blockedIps);
  }

  /**
   * Get all suspicious IPs
   */
  getSuspiciousIps(): string[] {
    return Array.from(this.suspiciousIps);
  }

  /**
   * Log rate limit violations and auto-block if threshold exceeded
   */
  logViolation(ip: string, userId?: string): void {
    const info = this.ipInfo.get(ip);
    if (!info) return;

    info.violationCount++;

    // Mark as suspicious after threshold
    if (info.violationCount >= this.violationThreshold && !info.suspicious) {
      this.markSuspicious(ip, `${info.violationCount} violations`);
    }

    // Auto-block after higher threshold
    if (info.violationCount >= this.blockThreshold && !info.blocked) {
      this.blockIp(ip, `${info.violationCount} violations - auto-blocked`);
    }

    this.logSecurityEvent('rate_limit_violation', ip, `Violation count: ${info.violationCount}`);
  }

  /**
   * Detect potential DDoS attacks
   * Analyzes request patterns to identify attacks
   */
  detectDDoS(timeWindow: number = 60000): DDoSDetectionResult {
    const now = Date.now();
    const cutoff = now - timeWindow;
    
    let totalRequests = 0;
    const activeIps: string[] = [];
    const suspiciousIps: string[] = [];

    for (const [ip, info] of this.ipInfo.entries()) {
      if (info.lastSeen.getTime() > cutoff) {
        activeIps.push(ip);
        totalRequests += info.requestCount;

        // Check for suspicious patterns
        if (info.requestCount > 100 || info.violationCount > 3) {
          suspiciousIps.push(ip);
        }
      }
    }

    // DDoS indicators:
    // 1. High request rate from many IPs
    // 2. Many IPs with violations
    // 3. Unusual spike in traffic

    const isDDoS = 
      (activeIps.length > 50 && totalRequests > 5000) || // Many IPs, high traffic
      (suspiciousIps.length > 20) || // Many suspicious IPs
      (totalRequests / activeIps.length > 200); // High average requests per IP

    let reason: string | undefined;
    if (isDDoS) {
      if (activeIps.length > 50 && totalRequests > 5000) {
        reason = 'High traffic from many IPs';
      } else if (suspiciousIps.length > 20) {
        reason = 'Many suspicious IPs detected';
      } else {
        reason = 'Unusual traffic spike';
      }
    }

    return {
      isDDoS,
      suspiciousIps,
      totalRequests,
      uniqueIps: activeIps.length,
      reason,
    };
  }

  /**
   * Implement DDoS protection measures
   */
  async activateDDoSProtection(): Promise<void> {
    const detection = this.detectDDoS();
    
    if (detection.isDDoS) {
      // Block all suspicious IPs
      for (const ip of detection.suspiciousIps) {
        if (!this.isBlocked(ip)) {
          this.blockIp(ip, 'DDoS protection activated');
        }
      }

      // Tighten global rate limits
      this.rateLimiter.setGlobalLimit({
        requestsPerMinute: 50,
        maxConcurrentConnections: 2,
        maxQueueSize: 20,
      });

      this.logSecurityEvent('ddos_protection_activated', 'system', 
        `Blocked ${detection.suspiciousIps.length} IPs`);
    }
  }

  /**
   * Deactivate DDoS protection and restore normal limits
   */
  async deactivateDDoSProtection(): Promise<void> {
    // Restore normal limits
    this.rateLimiter.setGlobalLimit(DEFAULT_IP_LIMIT);
    
    this.logSecurityEvent('ddos_protection_deactivated', 'system');
  }

  /**
   * Update IP information
   */
  private updateIpInfo(ip: string): void {
    let info = this.ipInfo.get(ip);
    
    if (!info) {
      info = {
        ip,
        requestCount: 0,
        violationCount: 0,
        firstSeen: new Date(),
        lastSeen: new Date(),
        blocked: false,
        suspicious: false,
      };
      this.ipInfo.set(ip, info);
    } else {
      info.lastSeen = new Date();
    }
  }

  /**
   * Log security events
   */
  private logSecurityEvent(eventType: string, ip: string, details?: string): void {
    const event = {
      timestamp: new Date().toISOString(),
      type: eventType,
      ip,
      details,
    };
    
    // In production, this would log to a security monitoring system
    console.log('[SECURITY]', JSON.stringify(event));
  }

  /**
   * Clean up old IP data
   */
  cleanup(maxAge: number = 86400000): void {
    const now = Date.now();
    
    for (const [ip, info] of this.ipInfo.entries()) {
      const age = now - info.lastSeen.getTime();
      
      // Remove old, non-blocked IPs
      if (age > maxAge && !info.blocked) {
        this.ipInfo.delete(ip);
        this.suspiciousIps.delete(ip);
      }
    }

    this.rateLimiter.cleanupOldBuckets(maxAge);
  }

  /**
   * Get statistics for monitoring
   */
  getStats(): {
    totalIps: number;
    blockedIps: number;
    suspiciousIps: number;
    recentViolations: number;
    ddosDetection: DDoSDetectionResult;
  } {
    const recentViolations = this.rateLimiter.getViolations(60000).length;
    const ddosDetection = this.detectDDoS();

    return {
      totalIps: this.ipInfo.size,
      blockedIps: this.blockedIps.size,
      suspiciousIps: this.suspiciousIps.size,
      recentViolations,
      ddosDetection,
    };
  }

  /**
   * Export blocked IPs for external firewall rules
   */
  exportBlockedIps(): Array<{ ip: string; reason: string; blockedAt: Date }> {
    return Array.from(this.blockedIps).map(ip => {
      const info = this.ipInfo.get(ip);
      return {
        ip,
        reason: `${info?.violationCount || 0} violations`,
        blockedAt: info?.lastSeen || new Date(),
      };
    });
  }
}
