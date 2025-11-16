/**
 * Metrics Aggregator
 * 
 * Handles time-series aggregation of metrics with multiple retention windows.
 * Stores raw metrics for 1 hour and aggregated metrics for 7 days.
 * Supports hourly and daily aggregation levels.
 * 
 * Requirements: 3.10
 */

/**
 * Raw metric snapshot at a point in time
 */
export interface RawMetricSnapshot {
  timestamp: Date;
  activeConnections: number;
  requestCount: number;
  successCount: number;
  errorCount: number;
  averageLatency: number;
  p95Latency: number;
  p99Latency: number;
  bytesReceived: number;
  bytesSent: number;
  requestsPerSecond: number;
  errorRate: number;
  activeUsers: number;
  memoryUsage: number;
  cpuUsage: number;
}

/**
 * Aggregated metric for a time window
 */
export interface AggregatedMetric {
  windowStart: Date;
  windowEnd: Date;
  aggregationLevel: 'hourly' | 'daily';
  
  // Aggregated values
  totalRequests: number;
  totalSuccessful: number;
  totalErrors: number;
  averageLatency: number;
  p95Latency: number;
  p99Latency: number;
  totalBytesReceived: number;
  totalBytesSent: number;
  averageActiveConnections: number;
  peakActiveConnections: number;
  averageErrorRate: number;
  averageActiveUsers: number;
  
  // Metadata
  sampleCount: number;
  timestamp: Date;
}

/**
 * Metrics aggregator for time-series data
 */
export class MetricsAggregator {
  // Raw metrics storage (1 hour retention)
  private rawMetrics: RawMetricSnapshot[] = [];
  private readonly rawRetentionMs = 3600000; // 1 hour
  
  // Hourly aggregates (7 days retention)
  private hourlyAggregates: AggregatedMetric[] = [];
  private readonly hourlyRetentionMs = 604800000; // 7 days
  
  // Daily aggregates (7 days retention)
  private dailyAggregates: AggregatedMetric[] = [];
  private readonly dailyRetentionMs = 604800000; // 7 days
  
  // Configuration
  private readonly maxRawMetrics: number;
  private readonly aggregationIntervalMs = 3600000; // 1 hour
  private lastAggregationTime: Date = new Date();

  constructor(maxRawMetrics: number = 3600) {
    this.maxRawMetrics = maxRawMetrics;
    
    // Start aggregation task
    this.startAggregationTask();
    
    // Start cleanup task
    this.startCleanupTask();
  }

  /**
   * Record a raw metric snapshot
   */
  recordMetric(snapshot: RawMetricSnapshot): void {
    this.rawMetrics.push(snapshot);
    
    // Trim raw metrics if needed
    if (this.rawMetrics.length > this.maxRawMetrics) {
      this.rawMetrics.shift();
    }
  }

  /**
   * Get raw metrics for a time window
   */
  getRawMetrics(windowMs: number = this.rawRetentionMs): RawMetricSnapshot[] {
    const now = Date.now();
    const cutoff = now - windowMs;
    
    return this.rawMetrics.filter(m => m.timestamp.getTime() > cutoff);
  }

  /**
   * Get hourly aggregates for a time window
   */
  getHourlyAggregates(windowMs: number = this.hourlyRetentionMs): AggregatedMetric[] {
    const now = Date.now();
    const cutoff = now - windowMs;
    
    return this.hourlyAggregates.filter(m => m.windowStart.getTime() > cutoff);
  }

  /**
   * Get daily aggregates for a time window
   */
  getDailyAggregates(windowMs: number = this.dailyRetentionMs): AggregatedMetric[] {
    const now = Date.now();
    const cutoff = now - windowMs;
    
    return this.dailyAggregates.filter(m => m.windowStart.getTime() > cutoff);
  }

  /**
   * Aggregate raw metrics into hourly buckets
   */
  private aggregateToHourly(): void {
    if (this.rawMetrics.length === 0) {
      return;
    }

    // Find the earliest raw metric
    const earliestTime = this.rawMetrics[0].timestamp.getTime();
    const now = Date.now();
    
    // Calculate hour boundaries
    const hourMs = 3600000;
    let hourStart = Math.floor(earliestTime / hourMs) * hourMs;
    
    while (hourStart < now) {
      const hourEnd = hourStart + hourMs;
      
      // Get metrics for this hour
      const metricsInHour = this.rawMetrics.filter(m => {
        const t = m.timestamp.getTime();
        return t >= hourStart && t < hourEnd;
      });
      
      if (metricsInHour.length > 0) {
        // Check if we already have an aggregate for this hour
        const existingAggregate = this.hourlyAggregates.find(
          a => a.windowStart.getTime() === hourStart
        );
        
        if (!existingAggregate) {
          const aggregate = this.createAggregate(
            metricsInHour,
            new Date(hourStart),
            new Date(hourEnd),
            'hourly'
          );
          this.hourlyAggregates.push(aggregate);
        }
      }
      
      hourStart = hourEnd;
    }
  }

  /**
   * Aggregate hourly metrics into daily buckets
   */
  private aggregateToDaily(): void {
    if (this.hourlyAggregates.length === 0) {
      return;
    }

    // Find the earliest hourly aggregate
    const earliestTime = this.hourlyAggregates[0].windowStart.getTime();
    const now = Date.now();
    
    // Calculate day boundaries
    const dayMs = 86400000;
    let dayStart = Math.floor(earliestTime / dayMs) * dayMs;
    
    while (dayStart < now) {
      const dayEnd = dayStart + dayMs;
      
      // Get hourly aggregates for this day
      const aggregatesInDay = this.hourlyAggregates.filter(a => {
        const t = a.windowStart.getTime();
        return t >= dayStart && t < dayEnd;
      });
      
      if (aggregatesInDay.length > 0) {
        // Check if we already have a daily aggregate for this day
        const existingAggregate = this.dailyAggregates.find(
          a => a.windowStart.getTime() === dayStart
        );
        
        if (!existingAggregate) {
          // Convert hourly aggregates to raw-like format for aggregation
          const rawLikeMetrics = aggregatesInDay.map(a => ({
            timestamp: a.windowStart,
            activeConnections: a.averageActiveConnections,
            requestCount: a.totalRequests,
            successCount: a.totalSuccessful,
            errorCount: a.totalErrors,
            averageLatency: a.averageLatency,
            p95Latency: a.p95Latency,
            p99Latency: a.p99Latency,
            bytesReceived: a.totalBytesReceived,
            bytesSent: a.totalBytesSent,
            requestsPerSecond: a.totalRequests / 3600, // Normalize to per-second
            errorRate: a.averageErrorRate,
            activeUsers: a.averageActiveUsers,
            memoryUsage: 0,
            cpuUsage: 0,
          }));
          
          const aggregate = this.createAggregate(
            rawLikeMetrics,
            new Date(dayStart),
            new Date(dayEnd),
            'daily'
          );
          this.dailyAggregates.push(aggregate);
        }
      }
      
      dayStart = dayEnd;
    }
  }

  /**
   * Create an aggregate from raw metrics
   */
  private createAggregate(
    metrics: RawMetricSnapshot[],
    windowStart: Date,
    windowEnd: Date,
    level: 'hourly' | 'daily'
  ): AggregatedMetric {
    if (metrics.length === 0) {
      return {
        windowStart,
        windowEnd,
        aggregationLevel: level,
        totalRequests: 0,
        totalSuccessful: 0,
        totalErrors: 0,
        averageLatency: 0,
        p95Latency: 0,
        p99Latency: 0,
        totalBytesReceived: 0,
        totalBytesSent: 0,
        averageActiveConnections: 0,
        peakActiveConnections: 0,
        averageErrorRate: 0,
        averageActiveUsers: 0,
        sampleCount: 0,
        timestamp: new Date(),
      };
    }

    // Calculate totals
    const totalRequests = metrics.reduce((sum, m) => sum + m.requestCount, 0);
    const totalSuccessful = metrics.reduce((sum, m) => sum + m.successCount, 0);
    const totalErrors = metrics.reduce((sum, m) => sum + m.errorCount, 0);
    const totalBytesReceived = metrics.reduce((sum, m) => sum + m.bytesReceived, 0);
    const totalBytesSent = metrics.reduce((sum, m) => sum + m.bytesSent, 0);

    // Calculate averages
    const averageLatency = metrics.reduce((sum, m) => sum + m.averageLatency, 0) / metrics.length;
    const p95Latencies = metrics.map(m => m.p95Latency).sort((a, b) => a - b);
    const p95Latency = p95Latencies[Math.floor(p95Latencies.length * 0.95)];
    const p99Latencies = metrics.map(m => m.p99Latency).sort((a, b) => a - b);
    const p99Latency = p99Latencies[Math.floor(p99Latencies.length * 0.99)];

    const averageActiveConnections = metrics.reduce((sum, m) => sum + m.activeConnections, 0) / metrics.length;
    const peakActiveConnections = Math.max(...metrics.map(m => m.activeConnections));
    const averageErrorRate = metrics.reduce((sum, m) => sum + m.errorRate, 0) / metrics.length;
    const averageActiveUsers = metrics.reduce((sum, m) => sum + m.activeUsers, 0) / metrics.length;

    return {
      windowStart,
      windowEnd,
      aggregationLevel: level,
      totalRequests,
      totalSuccessful,
      totalErrors,
      averageLatency,
      p95Latency,
      p99Latency,
      totalBytesReceived,
      totalBytesSent,
      averageActiveConnections,
      peakActiveConnections,
      averageErrorRate,
      averageActiveUsers,
      sampleCount: metrics.length,
      timestamp: new Date(),
    };
  }

  /**
   * Start aggregation task (runs every hour)
   */
  private startAggregationTask(): void {
    setInterval(() => {
      this.aggregateToHourly();
      this.aggregateToDaily();
      this.lastAggregationTime = new Date();
    }, this.aggregationIntervalMs);
  }

  /**
   * Start cleanup task (runs every hour)
   */
  private startCleanupTask(): void {
    setInterval(() => {
      this.cleanup();
    }, 3600000); // Every hour
  }

  /**
   * Clean up old data beyond retention windows
   */
  private cleanup(): void {
    const now = Date.now();
    
    // Clean raw metrics
    const rawCutoff = now - this.rawRetentionMs;
    this.rawMetrics = this.rawMetrics.filter(m => m.timestamp.getTime() > rawCutoff);
    
    // Clean hourly aggregates
    const hourlyCutoff = now - this.hourlyRetentionMs;
    this.hourlyAggregates = this.hourlyAggregates.filter(
      a => a.windowStart.getTime() > hourlyCutoff
    );
    
    // Clean daily aggregates
    const dailyCutoff = now - this.dailyRetentionMs;
    this.dailyAggregates = this.dailyAggregates.filter(
      a => a.windowStart.getTime() > dailyCutoff
    );
  }

  /**
   * Get metrics for a specific time window and aggregation level
   */
  getMetrics(
    windowMs: number,
    aggregationLevel: 'raw' | 'hourly' | 'daily' = 'raw'
  ): RawMetricSnapshot[] | AggregatedMetric[] {
    switch (aggregationLevel) {
      case 'raw':
        return this.getRawMetrics(windowMs);
      case 'hourly':
        return this.getHourlyAggregates(windowMs);
      case 'daily':
        return this.getDailyAggregates(windowMs);
      default:
        return this.getRawMetrics(windowMs);
    }
  }

  /**
   * Get statistics for a time window
   */
  getStatistics(
    windowMs: number,
    aggregationLevel: 'raw' | 'hourly' | 'daily' = 'raw'
  ): Record<string, any> {
    const metrics = this.getMetrics(windowMs, aggregationLevel);
    
    if (metrics.length === 0) {
      return {
        count: 0,
        averageRequests: 0,
        totalRequests: 0,
        averageLatency: 0,
        averageErrorRate: 0,
      };
    }

    if (aggregationLevel === 'raw') {
      const rawMetrics = metrics as RawMetricSnapshot[];
      return {
        count: rawMetrics.length,
        averageRequests: rawMetrics.reduce((sum, m) => sum + m.requestCount, 0) / rawMetrics.length,
        totalRequests: rawMetrics.reduce((sum, m) => sum + m.requestCount, 0),
        averageLatency: rawMetrics.reduce((sum, m) => sum + m.averageLatency, 0) / rawMetrics.length,
        averageErrorRate: rawMetrics.reduce((sum, m) => sum + m.errorRate, 0) / rawMetrics.length,
      };
    } else {
      const aggregates = metrics as AggregatedMetric[];
      return {
        count: aggregates.length,
        averageRequests: aggregates.reduce((sum, a) => sum + a.totalRequests, 0) / aggregates.length,
        totalRequests: aggregates.reduce((sum, a) => sum + a.totalRequests, 0),
        averageLatency: aggregates.reduce((sum, a) => sum + a.averageLatency, 0) / aggregates.length,
        averageErrorRate: aggregates.reduce((sum, a) => sum + a.averageErrorRate, 0) / aggregates.length,
      };
    }
  }

  /**
   * Reset all data
   */
  reset(): void {
    this.rawMetrics = [];
    this.hourlyAggregates = [];
    this.dailyAggregates = [];
    this.lastAggregationTime = new Date();
  }
}
