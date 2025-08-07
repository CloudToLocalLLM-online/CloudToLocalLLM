// Firebase initialization for CloudToLocalLLM web app
// This script initializes Firebase and provides authentication functions

// Import Firebase modules
import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-app.js';
import { getAuth, signInWithPopup, GoogleAuthProvider, signOut, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-auth.js';

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBvOkBwN6Ca6FNaOeMaMfeM1ZuPiKlBqMY",
  authDomain: "cloudtolocalllm-auth.firebaseapp.com",
  projectId: "cloudtolocalllm-auth",
  storageBucket: "cloudtolocalllm-auth.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456789"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const provider = new GoogleAuthProvider();

// Global Firebase functions for Flutter to call
window.firebaseAuth = {
  // Sign in with Google
  signInWithGoogle: async function() {
    try {
      const result = await signInWithPopup(auth, provider);
      const user = result.user;
      const token = await user.getIdToken();
      
      return {
        success: true,
        user: {
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          emailVerified: user.emailVerified
        },
        token: token
      };
    } catch (error) {
      console.error('Firebase sign-in error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  },

  // Sign out
  signOut: async function() {
    try {
      await signOut(auth);
      return { success: true };
    } catch (error) {
      console.error('Firebase sign-out error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  },

  // Get current user
  getCurrentUser: function() {
    const user = auth.currentUser;
    if (user) {
      return {
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
        emailVerified: user.emailVerified
      };
    }
    return null;
  },

  // Get ID token
  getIdToken: async function() {
    const user = auth.currentUser;
    if (user) {
      try {
        return await user.getIdToken();
      } catch (error) {
        console.error('Error getting ID token:', error);
        return null;
      }
    }
    return null;
  },

  // Listen to auth state changes
  onAuthStateChanged: function(callback) {
    return onAuthStateChanged(auth, (user) => {
      if (user) {
        callback({
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          emailVerified: user.emailVerified
        });
      } else {
        callback(null);
      }
    });
  }
};

console.log('Firebase Auth initialized for CloudToLocalLLM');
