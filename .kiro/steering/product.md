# Product Overview

CloudToLocalLLM is a cross-platform Flutter application that bridges cloud-based AI services with local AI models, providing a hybrid AI architecture with privacy-first design.

## Core Value Proposition

- Seamlessly switch between cloud AI (OpenAI, Anthropic) and local models (Ollama)
- Privacy-first: sensitive data stays local while leveraging cloud AI when needed
- Cross-platform: Windows, Linux, and Web support
- Secure tunneling for real-time communication between client and cloud services

## Key Components

- **Desktop Application**: Flutter-based native apps for Windows/Linux
- **Web Application**: Flutter web app hosted on Kubernetes
- **API Backend**: Node.js Express server for authentication and API routing
- **Streaming Proxy**: Multi-tenant proxy for WebSocket connections
- **Tunnel System**: Secure WebSocket tunneling for client-server communication

## Authentication & Security

- Auth0 OAuth2 authentication with JWT tokens
- Encrypted token storage using flutter_secure_storage
- User tier system (free, premium, enterprise)
- End-to-end encryption for all communications

## Target Users

- Developers and power users who want control over their AI interactions
- Privacy-conscious users who need local AI processing
- Organizations requiring self-hosted AI solutions
- Users who want flexibility between cloud and local AI models
