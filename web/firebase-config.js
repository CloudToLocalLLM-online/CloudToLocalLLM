// Firebase Configuration for CloudToLocalLLM Web App
// This configuration will be updated with actual Firebase project details

// Import the functions you need from the SDKs you need
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

// Your web app's Firebase configuration
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

// Initialize Firebase Authentication and get a reference to the service
const auth = getAuth(app);

export { auth, firebaseConfig };
