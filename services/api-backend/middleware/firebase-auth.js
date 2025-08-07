// CloudToLocalLLM - Firebase Authentication Middleware
// This middleware replaces Auth0 authentication with Firebase Authentication
// for better Google Cloud integration and cost savings

import admin from 'firebase-admin';

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

const initializeFirebase = () => {
  if (!firebaseInitialized && !admin.apps.length) {
    try {
      // In Cloud Run, use Application Default Credentials
      if (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.K_SERVICE) {
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          projectId: process.env.FIREBASE_PROJECT_ID || 'cloudtolocalllm-auth'
        });
      } else {
        // For local development, use service account key
        const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_KEY 
          ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY)
          : null;
          
        if (serviceAccount) {
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: process.env.FIREBASE_PROJECT_ID || 'cloudtolocalllm-auth'
          });
        } else {
          console.warn('Firebase credentials not found. Authentication will not work.');
          return false;
        }
      }
      
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

/**
 * Middleware to verify Firebase ID tokens
 * Replaces Auth0 JWT verification
 */
export const verifyFirebaseToken = async (req, res, next) => {
  try {
    // Initialize Firebase if not already done
    if (!initializeFirebase()) {
      return res.status(500).json({ 
        error: 'Authentication service not available',
        code: 'FIREBASE_NOT_INITIALIZED'
      });
    }

    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'No authentication token provided',
        code: 'NO_TOKEN'
      });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({ 
        error: 'Invalid token format',
        code: 'INVALID_TOKEN_FORMAT'
      });
    }

    // Verify the Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(token, true);
    
    // Extract user information
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name || decodedToken.display_name,
      picture: decodedToken.picture,
      emailVerified: decodedToken.email_verified,
      provider: decodedToken.firebase.sign_in_provider,
      authTime: new Date(decodedToken.auth_time * 1000),
      issuedAt: new Date(decodedToken.iat * 1000),
      expiresAt: new Date(decodedToken.exp * 1000)
    };

    // Add user metadata for logging
    req.userMetadata = {
      uid: decodedToken.uid,
      provider: decodedToken.firebase.sign_in_provider,
      authTime: decodedToken.auth_time
    };

    console.log(`User authenticated: ${req.user.email} (${req.user.uid})`);
    next();
    
  } catch (error) {
    console.error('Firebase token verification failed:', error);
    
    // Handle specific Firebase Auth errors
    let errorResponse = {
      error: 'Authentication failed',
      code: 'AUTH_FAILED'
    };

    if (error.code === 'auth/id-token-expired') {
      errorResponse = {
        error: 'Token has expired',
        code: 'TOKEN_EXPIRED'
      };
    } else if (error.code === 'auth/id-token-revoked') {
      errorResponse = {
        error: 'Token has been revoked',
        code: 'TOKEN_REVOKED'
      };
    } else if (error.code === 'auth/invalid-id-token') {
      errorResponse = {
        error: 'Invalid token',
        code: 'INVALID_TOKEN'
      };
    }

    res.status(401).json(errorResponse);
  }
};

/**
 * Optional middleware for routes that can work with or without authentication
 */
export const optionalFirebaseAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      // Try to authenticate, but don't fail if token is invalid
      await verifyFirebaseToken(req, res, () => {});
    }
    next();
  } catch (error) {
    // Continue without authentication
    next();
  }
};

/**
 * Middleware to check if user has specific permissions
 */
export const requirePermission = (permission) => {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ 
        error: 'Authentication required',
        code: 'AUTH_REQUIRED'
      });
    }

    try {
      // Get user's custom claims (permissions)
      const userRecord = await admin.auth().getUser(req.user.uid);
      const customClaims = userRecord.customClaims || {};
      
      if (customClaims.permissions && customClaims.permissions.includes(permission)) {
        next();
      } else {
        res.status(403).json({ 
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          required: permission
        });
      }
    } catch (error) {
      console.error('Permission check failed:', error);
      res.status(500).json({ 
        error: 'Permission check failed',
        code: 'PERMISSION_CHECK_FAILED'
      });
    }
  };
};

/**
 * Get user information by UID
 */
export const getUserInfo = async (uid) => {
  try {
    if (!initializeFirebase()) {
      throw new Error('Firebase not initialized');
    }
    
    const userRecord = await admin.auth().getUser(uid);
    return {
      uid: userRecord.uid,
      email: userRecord.email,
      name: userRecord.displayName,
      picture: userRecord.photoURL,
      emailVerified: userRecord.emailVerified,
      disabled: userRecord.disabled,
      metadata: {
        creationTime: userRecord.metadata.creationTime,
        lastSignInTime: userRecord.metadata.lastSignInTime
      },
      customClaims: userRecord.customClaims || {}
    };
  } catch (error) {
    console.error('Failed to get user info:', error);
    throw error;
  }
};

/**
 * Set custom claims for a user (permissions, roles, etc.)
 */
export const setUserClaims = async (uid, claims) => {
  try {
    if (!initializeFirebase()) {
      throw new Error('Firebase not initialized');
    }
    
    await admin.auth().setCustomUserClaims(uid, claims);
    console.log(`Custom claims set for user ${uid}:`, claims);
  } catch (error) {
    console.error('Failed to set custom claims:', error);
    throw error;
  }
};

/**
 * Health check for Firebase Auth service
 */
export const firebaseAuthHealthCheck = async () => {
  try {
    if (!initializeFirebase()) {
      return {
        status: 'unhealthy',
        error: 'Firebase not initialized'
      };
    }

    // Try to list users (limited) to verify connection
    await admin.auth().listUsers(1);
    
    return {
      status: 'healthy',
      service: 'firebase-auth',
      projectId: process.env.FIREBASE_PROJECT_ID,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      service: 'firebase-auth',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
};

export default {
  verifyFirebaseToken,
  optionalFirebaseAuth,
  requirePermission,
  getUserInfo,
  setUserClaims,
  firebaseAuthHealthCheck
};
