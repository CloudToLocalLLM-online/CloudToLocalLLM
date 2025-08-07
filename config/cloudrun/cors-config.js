// CloudToLocalLLM - CORS Configuration for Cloud Run
// This module provides CORS configuration optimized for Cloud Run deployment
// Handles cross-origin requests between Cloud Run services

const corsConfig = {
  // Cloud Run service domains
  cloudRunDomains: [
    '.run.app',
    '.a.run.app',
    'cloudtolocalllm.online',
    'app.cloudtolocalllm.online'
  ],
  
  // Development domains
  developmentDomains: [
    'localhost',
    '127.0.0.1',
    '0.0.0.0'
  ],
  
  // Get CORS configuration for Express
  getExpressConfig: function() {
    return {
      origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!origin) {
          return callback(null, true);
        }
        
        // Check if origin is allowed
        if (this.isOriginAllowed(origin)) {
          return callback(null, true);
        }
        
        // Log rejected origin for debugging
        console.warn(`CORS: Rejected origin: ${origin}`);
        return callback(new Error('Not allowed by CORS'), false);
      },
      
      credentials: true,
      
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
      
      allowedHeaders: [
        'Origin',
        'X-Requested-With',
        'Content-Type',
        'Accept',
        'Authorization',
        'Cache-Control',
        'X-Auth-Token',
        'X-API-Key'
      ],
      
      exposedHeaders: [
        'X-Total-Count',
        'X-Rate-Limit-Remaining',
        'X-Rate-Limit-Reset'
      ],
      
      maxAge: 86400, // 24 hours
      
      preflightContinue: false,
      optionsSuccessStatus: 200
    };
  },
  
  // Check if origin is allowed
  isOriginAllowed: function(origin) {
    try {
      const url = new URL(origin);
      const hostname = url.hostname;
      const protocol = url.protocol;
      
      // Only allow HTTPS in production (except localhost)
      if (process.env.NODE_ENV === 'production' && protocol !== 'https:' && !hostname.includes('localhost')) {
        return false;
      }
      
      // Check Cloud Run domains
      for (const domain of this.cloudRunDomains) {
        if (hostname.includes(domain) || hostname.endsWith(domain)) {
          return true;
        }
      }
      
      // Check development domains (only in non-production)
      if (process.env.NODE_ENV !== 'production') {
        for (const domain of this.developmentDomains) {
          if (hostname.includes(domain)) {
            return true;
          }
        }
      }
      
      // Check environment-specific allowed origins
      const envOrigins = process.env.CORS_ORIGINS;
      if (envOrigins) {
        const allowedOrigins = envOrigins.split(',').map(o => o.trim());
        if (allowedOrigins.includes(origin)) {
          return true;
        }
      }
      
      return false;
    } catch (error) {
      console.error('CORS: Error parsing origin:', error);
      return false;
    }
  },
  
  // Middleware for manual CORS handling
  middleware: function(req, res, next) {
    const origin = req.headers.origin;
    
    if (origin && this.isOriginAllowed(origin)) {
      res.header('Access-Control-Allow-Origin', origin);
      res.header('Access-Control-Allow-Credentials', 'true');
      res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS,PATCH');
      res.header('Access-Control-Allow-Headers', 'Origin,X-Requested-With,Content-Type,Accept,Authorization,Cache-Control,X-Auth-Token,X-API-Key');
      res.header('Access-Control-Expose-Headers', 'X-Total-Count,X-Rate-Limit-Remaining,X-Rate-Limit-Reset');
      res.header('Access-Control-Max-Age', '86400');
    }
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      res.status(200).end();
      return;
    }
    
    next();
  },
  
  // Get allowed origins list
  getAllowedOrigins: function() {
    const origins = [];
    
    // Add Cloud Run domains
    origins.push(...this.cloudRunDomains.map(domain => `https://*${domain}`));
    
    // Add development domains (if not production)
    if (process.env.NODE_ENV !== 'production') {
      origins.push(...this.developmentDomains.map(domain => `http://${domain}:*`));
      origins.push(...this.developmentDomains.map(domain => `https://${domain}:*`));
    }
    
    // Add environment-specific origins
    const envOrigins = process.env.CORS_ORIGINS;
    if (envOrigins) {
      origins.push(...envOrigins.split(',').map(o => o.trim()));
    }
    
    return origins;
  },
  
  // Log CORS configuration
  logConfig: function() {
    console.log('CORS Configuration:');
    console.log('  Environment:', process.env.NODE_ENV || 'development');
    console.log('  Cloud Run domains:', this.cloudRunDomains);
    
    if (process.env.NODE_ENV !== 'production') {
      console.log('  Development domains:', this.developmentDomains);
    }
    
    const envOrigins = process.env.CORS_ORIGINS;
    if (envOrigins) {
      console.log('  Environment origins:', envOrigins.split(','));
    }
    
    console.log('  Total allowed origins:', this.getAllowedOrigins().length);
  }
};

module.exports = corsConfig;
