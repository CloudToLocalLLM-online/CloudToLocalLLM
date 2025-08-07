// Firebase Configuration for CloudToLocalLLM Web App
// This configuration will be updated with actual Firebase project details

// Import the functions you need from the SDKs you need
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBvOkBwN6Ca6FNaOeMaMfeM1ZuPiKlBqMY",
  authDomain: "cloudtolocalllm-468303.firebaseapp.com",
  projectId: "cloudtolocalllm-468303",
  storageBucket: "cloudtolocalllm-468303.appspot.com",
  messagingSenderId: "923995245673",
  appId: "1:923995245673:web:cloudtolocalllm"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
const auth = getAuth(app);

export { auth, firebaseConfig };
