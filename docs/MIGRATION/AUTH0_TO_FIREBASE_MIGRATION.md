# CloudToLocalLLM: Auth0 to Firebase Authentication Migration Plan

## 🎯 **Migration Overview**

This document outlines the migration from Auth0 to Firebase Authentication for CloudToLocalLLM, deployed on Google Cloud Run with subdomain architecture.

## ⏱️ **Realistic Timeline: 3-4 Weeks**

### **Phase 1: Setup & Planning (Week 1)**
- **Days 1-2**: Firebase project setup and configuration
- **Days 3-4**: Development environment setup and testing
- **Days 5-7**: Parallel implementation planning and code review

### **Phase 2: Backend Migration (Week 2)**
- **Days 1-3**: Update Node.js API authentication middleware
- **Days 4-5**: Update CORS and environment configurations
- **Days 6-7**: Backend testing and API endpoint validation

### **Phase 3: Frontend Migration (Week 3)**
- **Days 1-4**: Update Flutter web app authentication
- **Days 5-6**: Update UI components and error handling
- **Day 7**: Frontend testing and integration validation

### **Phase 4: Deployment & Validation (Week 4)**
- **Days 1-2**: Staging deployment and comprehensive testing
- **Days 3-4**: Production deployment with gradual rollout
- **Days 5-7**: Monitoring, bug fixes, and Auth0 cleanup

## 📋 **Detailed Implementation Plan**

### **Phase 1: Setup & Planning (Week 1)**

#### Day 1-2: Firebase Project Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and create project
firebase login
firebase projects:create cloudtolocalllm-auth

# Initialize Firebase in project
cd CloudToLocalLLM
firebase init auth
```

#### Day 3-4: Development Environment
```bash
# Install Firebase dependencies
cd services/api-backend
npm install firebase-admin

cd ../../web
# Add Firebase to Flutter pubspec.yaml
```

#### Day 5-7: Planning & Architecture Review
- Review current Auth0 integration points
- Plan migration strategy for user data
- Design rollback procedures
- Create testing checklist

### **Phase 2: Backend Migration (Week 2)**

#### Day 1-3: API Authentication Middleware

**Update `services/api-backend/middleware/firebase-auth.js`:**
```javascript
import admin from 'firebase-admin';

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: process.env.FIREBASE_PROJECT_ID
  });
}

export const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name,
      picture: decodedToken.picture
    };
    
    next();
  } catch (error) {
    console.error('Firebase token verification failed:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
};
```

#### Day 4-5: Environment Configuration

**Update `config/cloudrun/.env.cloudrun.template`:**
```bash
# Remove Auth0 variables
# AUTH0_DOMAIN=your-auth0-domain.auth0.com
# AUTH0_CLIENT_ID=your-auth0-client-id
# AUTH0_CLIENT_SECRET=your-auth0-client-secret

# Add Firebase variables
FIREBASE_PROJECT_ID=cloudtolocalllm-auth
GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json
```

#### Day 6-7: Backend Testing
- Unit tests for new authentication middleware
- Integration tests with Cloud Run services
- API endpoint validation

### **Phase 3: Frontend Migration (Week 3)**

#### Day 1-4: Flutter Web App Updates

**Update `web/pubspec.yaml`:**
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  google_sign_in: ^6.1.5
```

**Create `lib/services/firebase_auth_service.dart`:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: 'your-google-client-id.googleusercontent.com',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Email sign in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }
}
```

#### Day 5-6: UI Components Update
- Update login/logout buttons
- Update authentication state management
- Update error handling and user feedback

#### Day 7: Frontend Testing
- Authentication flow testing
- Token management validation
- UI/UX testing

### **Phase 4: Deployment & Validation (Week 4)**

#### Day 1-2: Staging Deployment

**Update Cloud Run services:**
```bash
# Update API service with Firebase configuration
gcloud run services update cloudtolocalllm-api \
  --region=us-east4 \
  --set-env-vars="FIREBASE_PROJECT_ID=cloudtolocalllm-auth" \
  --quiet

# Deploy updated services to staging
gcloud builds triggers run cloudtolocalllm-trigger --branch=firebase-auth
```

#### Day 3-4: Production Deployment

**Gradual rollout strategy:**
1. Deploy to 10% of traffic
2. Monitor for 24 hours
3. Increase to 50% if stable
4. Full rollout if no issues

#### Day 5-7: Monitoring & Cleanup
- Monitor authentication metrics
- Fix any discovered issues
- Clean up Auth0 configuration
- Update documentation

## 🔧 **Configuration Updates Required**

### **1. Cloud Run Environment Variables**
```bash
# Remove
AUTH0_DOMAIN
AUTH0_CLIENT_ID
AUTH0_CLIENT_SECRET

# Add
FIREBASE_PROJECT_ID=cloudtolocalllm-auth
```

### **2. CORS Configuration**
```javascript
// Update config/cloudrun/cors-config.js
const corsOrigins = [
  'https://cloudtolocalllm.online',
  'https://app.cloudtolocalllm.online',
  'https://cloudtolocalllm-auth.firebaseapp.com'
];
```

### **3. Subdomain Configuration**
```json
// Update config/cloudrun/subdomain-config.json
{
  "authentication": {
    "provider": "firebase",
    "domain": "cloudtolocalllm-auth.firebaseapp.com",
    "customDomain": "auth.cloudtolocalllm.online"
  }
}
```

## 📊 **Testing Checklist**

### **Backend Testing**
- [ ] Token validation works correctly
- [ ] User data extraction is accurate
- [ ] Error handling for invalid tokens
- [ ] CORS configuration allows subdomain requests
- [ ] API endpoints return correct user information

### **Frontend Testing**
- [ ] Google Sign-In flow works
- [ ] Email/password authentication works
- [ ] Token refresh happens automatically
- [ ] Sign-out clears all authentication state
- [ ] Protected routes redirect correctly

### **Integration Testing**
- [ ] API calls include correct authentication headers
- [ ] Cross-subdomain authentication works
- [ ] User sessions persist across page reloads
- [ ] Authentication state syncs across tabs

## 🚨 **Rollback Plan**

If issues arise during migration:

1. **Immediate Rollback** (< 5 minutes):
   ```bash
   # Revert to previous Cloud Run revision
   gcloud run services update-traffic cloudtolocalllm-api \
     --to-revisions=PREVIOUS_REVISION=100
   ```

2. **Configuration Rollback** (< 15 minutes):
   - Restore Auth0 environment variables
   - Revert CORS configuration
   - Restore Auth0 middleware

3. **Full Rollback** (< 30 minutes):
   - Deploy previous Git commit
   - Restore all Auth0 configurations
   - Verify all services are working

## 💰 **Cost Impact**

### **Before Migration (Auth0)**
- Essentials Plan: $23/month
- Professional Plan: $240/month (if advanced features needed)

### **After Migration (Firebase Auth)**
- 0-50,000 users: $0/month
- 50,000+ users: $0.0055 per verification

### **Estimated Savings**
- **Year 1**: $276 - $2,880 saved
- **Year 2+**: Even more as user base grows

## 🎯 **Success Metrics**

- [ ] 100% of users can authenticate successfully
- [ ] Authentication latency < 500ms
- [ ] Zero authentication-related errors
- [ ] Cost reduction of $23-240/month achieved
- [ ] All subdomain authentication flows working

## 📚 **Resources**

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Flutter Firebase Auth](https://firebase.flutter.dev/docs/auth/overview)
- [Google Cloud Run with Firebase](https://cloud.google.com/run/docs/tutorials/identity-platform)

---

**Migration Lead**: Development Team  
**Timeline**: 3-4 weeks  
**Risk Level**: Medium  
**Expected Savings**: $276-2,880/year
