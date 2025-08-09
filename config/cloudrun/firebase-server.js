import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import admin from 'firebase-admin';

const app = express();
const port = process.env.PORT || 8080;

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

const initializeFirebase = () => {
  if (!firebaseInitialized && !admin.apps.length) {
    try {
      // In Cloud Run, use Application Default Credentials
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID || 'cloudtolocalllm-auth'
      });
      
      firebaseInitialized = true;
      console.log('Firebase Admin SDK initialized successfully');
      return true;
    } catch (error) {
      console.error('Failed to initialize Firebase Admin SDK:', error);
      return false;
    }
  }
  return firebaseInitialized;
};

// CORS configuration: allow project domains and Cloud Run *.run.app origins
const staticCorsOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(origin => origin.trim())
  : [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'https://api.cloudtolocalllm.online',
      'https://streaming.cloudtolocalllm.online'
    ];

// Origin check helper for run.app and project domains
const isAllowedOrigin = (origin) => {
  if (!origin) return true; // non-browser or same-origin
  try {
    const url = new URL(origin);
    const host = url.hostname;
    if (staticCorsOrigins.includes(origin)) return true;
    // Allow any Cloud Run service default domain
    if (host.endsWith('.run.app') || host.endsWith('.a.run.app')) return true;
    // Allow any subdomain of our primary domain
    if (host === 'cloudtolocalllm.online' || host.endsWith('.cloudtolocalllm.online')) return true;
  } catch (_) {
    // If origin isn't a valid URL, be conservative and deny
    return false;
  }
  return false;
};

console.log('CloudToLocalLLM API with Firebase Auth starting...');
console.log('Port:', port);
console.log('Firebase Project:', process.env.FIREBASE_PROJECT_ID);
console.log('CORS Origins (static):', staticCorsOrigins);

// Initialize Firebase
const firebaseReady = initializeFirebase();

// Middleware
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      // Allow connections to our domains and Cloud Run default domains
      connectSrc: ["'self'", ...staticCorsOrigins, 'https://*.run.app', 'https://*.a.run.app'],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: (origin, callback) => {
    if (isAllowedOrigin(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-API-Key'],
  exposedHeaders: ['X-Total-Count', 'X-Rate-Limit-Remaining']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Firebase Auth Middleware
const verifyFirebaseToken = async (req, res, next) => {
  try {
    if (!firebaseReady) {
      return res.status(500).json({ 
        error: 'Authentication service not available',
        code: 'FIREBASE_NOT_INITIALIZED'
      });
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'No authentication token provided',
        code: 'NO_TOKEN'
      });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token, true);
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name || decodedToken.display_name,
      picture: decodedToken.picture,
      emailVerified: decodedToken.email_verified,
      provider: decodedToken.firebase.sign_in_provider
    };

    next();
  } catch (error) {
    console.error('Firebase token verification failed:', error);
    res.status(401).json({ 
      error: 'Authentication failed',
      code: 'AUTH_FAILED'
    });
  }
};

// Health endpoints (no auth required)
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'cloudtolocalllm-api',
    version: '1.0.0',
    port: port,
    firebase: {
      initialized: firebaseInitialized,
      projectId: process.env.FIREBASE_PROJECT_ID
    },
    cors: staticCorsOrigins,
    environment: process.env.NODE_ENV || 'development'
  };
  
  res.json(healthStatus);
});

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(), 
    service: 'cloudtolocalllm-api',
    endpoint: '/api/health',
    firebase: firebaseInitialized
  });
});

// Firebase Auth health check
app.get('/api/auth/health', (req, res) => {
  res.json({
    status: firebaseInitialized ? 'healthy' : 'unhealthy',
    service: 'firebase-auth',
    projectId: process.env.FIREBASE_PROJECT_ID,
    timestamp: new Date().toISOString()
  });
});

// Protected API endpoints
app.get('/api/user', verifyFirebaseToken, (req, res) => {
  res.json({
    user: req.user,
    message: 'User authenticated successfully'
  });
});

app.get('/api/models', verifyFirebaseToken, (req, res) => {
  res.json({ 
    models: [
      { id: 'llama2', name: 'Llama 2', status: 'available' },
      { id: 'codellama', name: 'Code Llama', status: 'available' }
    ], 
    message: 'Models endpoint with Firebase auth',
    user: req.user.email
  });
});

// Public endpoints (no auth required)
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    service: 'cloudtolocalllm-api',
    authentication: 'firebase',
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('API Error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.originalUrl,
    method: req.method
  });
});

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`CloudToLocalLLM API listening on port ${port}`);
  console.log(`Health endpoint: http://0.0.0.0:${port}/health`);
  console.log(`Firebase Auth: ${firebaseInitialized ? 'Ready' : 'Not initialized'}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
