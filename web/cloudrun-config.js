// CloudToLocalLLM - Cloud Run Configuration
// This file provides configuration for the Flutter web app when running on Cloud Run
// It handles service discovery, API endpoints, and environment-specific settings

window.cloudRunConfig = {
  // Environment detection
  isCloudRun: window.location.hostname.includes('.run.app') || 
              window.location.hostname.includes('cloudtolocalllm'),
  
  // Production subdomain URLs (defaults)
  services: {
    api: {
      baseUrl: 'https://api.cloudtolocalllm.online',
      endpoints: {
        health: '/health',
        auth: '/api/auth',
        models: '/api/models',
        chat: '/api/chat',
        streaming: '/api/streaming',
        tunnel: '/api/tunnel',
        bridge: '/api/bridge'
      }
    },
    streaming: {
      baseUrl: 'https://streaming.cloudtolocalllm.online',
      endpoints: {
        health: '/health',
        proxy: '/proxy',
        websocket: '/ws'
      }
    }
  },

  // API configuration for Cloud Run
  api: {
    timeout: 30000, // 30 seconds
    retries: 3,
    retryDelay: 1000, // 1 second
    
    // Headers for Cloud Run requests
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest'
    },
    
    // CORS configuration
    cors: {
      credentials: 'include',
      mode: 'cors'
    }
  },
  
  // Feature flags for Cloud Run environment
  features: {
    localOllama: false, // Disable local Ollama connections
    tunneling: true,    // Enable tunneling through API service
    streaming: true,    // Enable streaming responses
    auth: true,         // Enable authentication
    monitoring: true    // Enable monitoring and analytics
  },
  
  // Fallback endpoints for development/testing
  fallback: {
    // These will be used if the main services are not available
    endpoints: [
      'http://localhost:8080',  // Local development
      'http://localhost:3000',  // Alternative local port
    ]
  },
  
  // Service discovery and health checking
  discovery: {
    healthCheckInterval: 30000, // 30 seconds
    maxRetries: 5,
    services: []
  },
  
  // Initialize service discovery
  init: async function() {
    console.log('CloudToLocalLLM: Initializing Cloud Run configuration...');

    // If running on *.run.app, derive API/Streaming service base URLs from known naming convention
    if (this.isCloudRun) {
      try {
        const host = window.location.hostname; // e.g., cloudtolocalllm-web-<hash>-<region>.a.run.app
        const apiHost = host.replace('web-', 'api-').replace('web.', 'api.');
        const streamingHost = host.replace('web-', 'streaming-').replace('web.', 'streaming.');
        // Only apply if endsWith .run.app
        if (host.endsWith('.run.app') || host.endsWith('.a.run.app')) {
          this.services.api.baseUrl = `https://${apiHost}`;
          this.services.streaming.baseUrl = `https://${streamingHost}`;
          console.log('CloudToLocalLLM: Derived service base URLs from run.app host:', this.services);
        }
      } catch (e) {
        console.warn('CloudToLocalLLM: Failed to derive run.app service URLs:', e.message);
      }
    }

    if (!this.isCloudRun) {
      console.log('CloudToLocalLLM: Not running on Cloud Run, using default configuration');
      return;
    }

    try {
      // Discover available services
      await this.discoverServices();

      // Start health monitoring
      this.startHealthMonitoring();

      console.log('CloudToLocalLLM: Cloud Run configuration initialized successfully');
    } catch (error) {
      console.error('CloudToLocalLLM: Failed to initialize Cloud Run configuration:', error);
    }
  },

  // Discover available services
  discoverServices: async function() {
    console.log('CloudToLocalLLM: Discovering services...');
    
    const services = ['api', 'streaming'];
    const discovered = [];
    
    for (const service of services) {
      try {
        const baseUrl = this.services[service].baseUrl;
        const healthUrl = baseUrl + this.services[service].endpoints.health;
        
        console.log(`CloudToLocalLLM: Checking service ${service} at ${healthUrl}`);
        
        const response = await fetch(healthUrl, {
          method: 'GET',
          headers: this.api.headers,
          ...this.api.cors,
          signal: AbortSignal.timeout(5000) // 5 second timeout
        });
        
        if (response.ok) {
          const health = await response.json();
          discovered.push({
            name: service,
            url: baseUrl,
            status: 'healthy',
            health: health
          });
          console.log(`CloudToLocalLLM: Service ${service} is healthy`);
        } else {
          console.warn(`CloudToLocalLLM: Service ${service} health check failed:`, response.status);
        }
      } catch (error) {
        console.warn(`CloudToLocalLLM: Service ${service} discovery failed:`, error.message);
      }
    }
    
    this.discovery.services = discovered;
    console.log(`CloudToLocalLLM: Discovered ${discovered.length} healthy services`);
  },
  
  // Start health monitoring
  startHealthMonitoring: function() {
    if (this.discovery.healthCheckInterval > 0) {
      setInterval(() => {
        this.discoverServices();
      }, this.discovery.healthCheckInterval);
      
      console.log(`CloudToLocalLLM: Health monitoring started (interval: ${this.discovery.healthCheckInterval}ms)`);
    }
  },
  
  // Get API base URL
  getApiUrl: function() {
    const apiService = this.discovery.services.find(s => s.name === 'api');
    return apiService ? apiService.url : this.services.api.baseUrl;
  },
  
  // Get streaming URL
  getStreamingUrl: function() {
    const streamingService = this.discovery.services.find(s => s.name === 'streaming');
    return streamingService ? streamingService.url : this.services.streaming.baseUrl;
  },
  
  // Make API request with Cloud Run optimizations
  apiRequest: async function(endpoint, options = {}) {
    const baseUrl = this.getApiUrl();
    const url = baseUrl + endpoint;
    
    const requestOptions = {
      ...this.api.cors,
      headers: {
        ...this.api.headers,
        ...options.headers
      },
      ...options
    };
    
    let lastError;
    
    for (let attempt = 1; attempt <= this.api.retries; attempt++) {
      try {
        console.log(`CloudToLocalLLM: API request attempt ${attempt}/${this.api.retries}: ${url}`);
        
        const response = await fetch(url, {
          ...requestOptions,
          signal: AbortSignal.timeout(this.api.timeout)
        });
        
        if (response.ok) {
          return response;
        } else {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
      } catch (error) {
        lastError = error;
        console.warn(`CloudToLocalLLM: API request attempt ${attempt} failed:`, error.message);
        
        if (attempt < this.api.retries) {
          await new Promise(resolve => setTimeout(resolve, this.api.retryDelay * attempt));
        }
      }
    }
    
    throw lastError;
  },
  
  // Check if a feature is enabled
  isFeatureEnabled: function(feature) {
    return this.features[feature] === true;
  },
  
  // Get service status
  getServiceStatus: function() {
    return {
      isCloudRun: this.isCloudRun,
      discoveredServices: this.discovery.services.length,
      services: this.discovery.services.map(s => ({
        name: s.name,
        url: s.url,
        status: s.status
      })),
      features: this.features
    };
  }
};

// Auto-initialize when the script loads
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.cloudRunConfig.init();
  });
} else {
  window.cloudRunConfig.init();
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = window.cloudRunConfig;
}
