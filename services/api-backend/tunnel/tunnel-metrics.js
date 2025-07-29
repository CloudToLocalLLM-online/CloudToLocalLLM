/**
 * @fileoverview Tunnel Metrics Collection and Monitoring
 * Provides comprehensive metrics for the tunnel system including
 * connection counts, latency, throughput, and error rates
 */

import { EventEmitter } from 'events';

/**
 * Tunnel metrics collector with Prometheus-compatible format
 */
export class TunnelMetrics extends EventEmitter {
  constructor() {
    super();

    this.counters = new Map();
    this.gauges = new Map();
    this.histograms = new Map();
    this.startTime = Date.now();

    this.initializeMetrics();
  }

  /**
   * Initialize default metrics
   */
  initializeMetrics() {
    // Connection metrics
    this.counters.set('connections_established', 0);
    this.counters.set('connections_closed', 0);
    this.counters.set('connections_rejected_limit', 0);
    this.counters.set('connections_rejected_auth', 0);
    this.counters.set('connections_rejected_error', 0);
    this.counters.set('connection_errors', 0);

    // Message metrics
    this.counters.set('messages_received', 0);
    this.counters.set('messages_sent', 0);
    this.counters.set('messages_unknown', 0);
    this.counters.set('message_errors', 0);

    // Request metrics
    this.counters.set('requests_sent', 0);
    this.counters.set('requests_completed', 0);
    this.counters.set('requests_failed', 0);
    this.counters.set('requests_timeout', 0);

    // Security metrics
    this.counters.set('auth_attempts_total', 0);
    this.counters.set('auth_failures', 0);
    this.counters.set('security_events', 0);
    this.counters.set('rate_limit_violations', 0);

    // Server metrics
    this.counters.set('server_errors', 0);

    // Gauges
    this.gauges.set('active_connections', 0);
    this.gauges.set('pending_requests', 0);
    this.gauges.set('memory_usage_bytes', 0);
    this.gauges.set('cpu_usage_percent', 0);

    // Histograms (store buckets and counts)
    this.histograms.set('message_latency_seconds', {
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
      counts: new Array(8).fill(0),
      sum: 0,
      count: 0,
    });

    this.histograms.set('request_duration_seconds', {
      buckets: [0.1, 0.5, 1, 2, 5, 10, 30],
      counts: new Array(7).fill(0),
      sum: 0,
      count: 0,
    });

    this.histograms.set('connection_duration_seconds', {
      buckets: [60, 300, 900, 1800, 3600, 7200, 14400],
      counts: new Array(7).fill(0),
      sum: 0,
      count: 0,
    });
  }

  /**
   * Increment a counter metric
   */
  incrementCounter(name, value = 1, labels = {}) {
    const key = this.getMetricKey(name, labels);
    const current = this.counters.get(key) || 0;
    this.counters.set(key, current + value);

    this.emit('counter_updated', { name, value, labels, total: current + value });
  }

  /**
   * Set a gauge metric
   */
  setGauge(name, value, labels = {}) {
    const key = this.getMetricKey(name, labels);
    this.gauges.set(key, value);

    this.emit('gauge_updated', { name, value, labels });
  }

  /**
   * Record a histogram observation
   */
  recordHistogram(name, value, labels = {}) {
    const key = this.getMetricKey(name, labels);
    const histogram = this.histograms.get(key);

    if (!histogram) {
      throw new Error(`Histogram ${name} not found`);
    }

    // Update sum and count
    histogram.sum += value;
    histogram.count += 1;

    // Update bucket counts
    for (let i = 0; i < histogram.buckets.length; i++) {
      if (value <= histogram.buckets[i]) {
        histogram.counts[i] += 1;
      }
    }

    this.emit('histogram_updated', { name, value, labels });
  }

  /**
   * Get metric key with labels
   */
  getMetricKey(name, labels = {}) {
    if (Object.keys(labels).length === 0) {
      return name;
    }

    const labelString = Object.entries(labels)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, value]) => `${key}="${value}"`)
      .join(',');

    return `${name}{${labelString}}`;
  }

  /**
   * Get all metrics in Prometheus format
   */
  getPrometheusMetrics() {
    const lines = [];

    // Add metadata
    lines.push('# HELP tunnel_info Tunnel server information');
    lines.push('# TYPE tunnel_info gauge');
    lines.push('tunnel_info{version="1.0.0"} 1');

    lines.push('# HELP tunnel_uptime_seconds Tunnel server uptime in seconds');
    lines.push('# TYPE tunnel_uptime_seconds gauge');
    lines.push(`tunnel_uptime_seconds ${(Date.now() - this.startTime) / 1000}`);

    // Counters
    for (const [key, value] of this.counters) {
      const metricName = `tunnel_${key}`;
      lines.push(`# HELP ${metricName} ${this.getMetricHelp(key)}`);
      lines.push(`# TYPE ${metricName} counter`);
      lines.push(`${metricName} ${value}`);
    }

    // Gauges
    for (const [key, value] of this.gauges) {
      const metricName = `tunnel_${key}`;
      lines.push(`# HELP ${metricName} ${this.getMetricHelp(key)}`);
      lines.push(`# TYPE ${metricName} gauge`);
      lines.push(`${metricName} ${value}`);
    }

    // Histograms
    for (const [key, histogram] of this.histograms) {
      const metricName = `tunnel_${key}`;
      lines.push(`# HELP ${metricName} ${this.getMetricHelp(key)}`);
      lines.push(`# TYPE ${metricName} histogram`);

      // Bucket counts
      for (let i = 0; i < histogram.buckets.length; i++) {
        lines.push(`${metricName}_bucket{le="${histogram.buckets[i]}"} ${histogram.counts[i]}`);
      }
      lines.push(`${metricName}_bucket{le="+Inf"} ${histogram.count}`);

      // Sum and count
      lines.push(`${metricName}_sum ${histogram.sum}`);
      lines.push(`${metricName}_count ${histogram.count}`);
    }

    return lines.join('\n');
  }

  /**
   * Get metric help text
   */
  getMetricHelp(metricName) {
    const helpTexts = {
      connections_established: 'Total number of tunnel connections established',
      connections_closed: 'Total number of tunnel connections closed',
      connections_rejected_limit: 'Total number of connections rejected due to limit',
      connections_rejected_auth: 'Total number of connections rejected due to authentication',
      connections_rejected_error: 'Total number of connections rejected due to errors',
      connection_errors: 'Total number of connection errors',
      messages_received: 'Total number of messages received',
      messages_sent: 'Total number of messages sent',
      messages_unknown: 'Total number of unknown message types received',
      message_errors: 'Total number of message processing errors',
      requests_sent: 'Total number of HTTP requests sent to clients',
      requests_completed: 'Total number of HTTP requests completed successfully',
      requests_failed: 'Total number of HTTP requests that failed',
      requests_timeout: 'Total number of HTTP requests that timed out',
      auth_attempts_total: 'Total number of authentication attempts',
      auth_failures: 'Total number of authentication failures',
      security_events: 'Total number of security events detected',
      rate_limit_violations: 'Total number of rate limit violations',
      server_errors: 'Total number of server errors',
      active_connections: 'Current number of active tunnel connections',
      pending_requests: 'Current number of pending HTTP requests',
      memory_usage_bytes: 'Current memory usage in bytes',
      cpu_usage_percent: 'Current CPU usage percentage',
      message_latency_seconds: 'Message processing latency in seconds',
      request_duration_seconds: 'HTTP request duration in seconds',
      connection_duration_seconds: 'Connection duration in seconds',
    };

    return helpTexts[metricName] || 'No description available';
  }

  /**
   * Get metrics summary
   */
  getMetrics() {
    return {
      counters: Object.fromEntries(this.counters),
      gauges: Object.fromEntries(this.gauges),
      histograms: this.getHistogramSummary(),
      uptime: (Date.now() - this.startTime) / 1000,
    };
  }

  /**
   * Get histogram summary
   */
  getHistogramSummary() {
    const summary = {};

    for (const [name, histogram] of this.histograms) {
      summary[name] = {
        count: histogram.count,
        sum: histogram.sum,
        average: histogram.count > 0 ? histogram.sum / histogram.count : 0,
        buckets: histogram.buckets.map((bucket, i) => ({
          le: bucket,
          count: histogram.counts[i],
        })),
      };
    }

    return summary;
  }

  /**
   * Calculate percentiles for histogram
   */
  calculatePercentile(histogramName, percentile) {
    const histogram = this.histograms.get(histogramName);
    if (!histogram || histogram.count === 0) {
      return 0;
    }

    const targetCount = Math.ceil((percentile / 100) * histogram.count);
    let cumulativeCount = 0;

    for (let i = 0; i < histogram.buckets.length; i++) {
      cumulativeCount += histogram.counts[i];
      if (cumulativeCount >= targetCount) {
        return histogram.buckets[i];
      }
    }

    return histogram.buckets[histogram.buckets.length - 1];
  }

  /**
   * Reset all metrics
   */
  reset() {
    this.counters.clear();
    this.gauges.clear();
    this.histograms.clear();
    this.startTime = Date.now();
    this.initializeMetrics();

    this.emit('metrics_reset');
  }

  /**
   * Update system metrics
   */
  updateSystemMetrics() {
    const memUsage = process.memoryUsage();
    this.setGauge('memory_usage_bytes', memUsage.heapUsed);

    // CPU usage would require additional monitoring
    // For now, we'll set it to 0 as a placeholder
    this.setGauge('cpu_usage_percent', 0);
  }

  /**
   * Start periodic system metrics collection
   */
  startSystemMetricsCollection(interval = 30000) {
    this.systemMetricsInterval = setInterval(() => {
      this.updateSystemMetrics();
    }, interval);
  }

  /**
   * Stop periodic system metrics collection
   */
  stopSystemMetricsCollection() {
    if (this.systemMetricsInterval) {
      clearInterval(this.systemMetricsInterval);
      this.systemMetricsInterval = null;
    }
  }
}
