// CloudToLocalLLM Runtime Configuration
window.cloudToLocalLLMConfig = {
  // API endpoints
  apiEndpoint: 'https://api.cloudtolocalllm.online',
  wsEndpoint: 'wss://api.cloudtolocalllm.online/ws/tunnel',
  
  // TURN server for WebRTC
  turnServer: {
    urls: [
      'turn:174.138.115.184:3478',
      'turn:174.138.115.184:5349'
    ],
    username: 'cloudtolocalllm',
    credential: '' // TODO: Inject securely or fetch from API
  },
  
  // Environment
  environment: 'production',
  
  // Features
  enableAnalytics: false,
  enableSentry: false,
  
  // Auth (SuperTokens)
  authDomain: 'https://auth.cloudtolocalllm.online',
  appDomain: 'https://app.cloudtolocalllm.online'
};

