# Quick Start Guide

This guide will help you get CloudToLocalLLM up and running quickly.

## Basic Setup

1. Install Dependencies:
```powershell
flutter pub get  # Flutter dependencies
npm install     # Node.js dependencies
```

2. Start Development Environment:
```powershell
# Terminal 1: Flutter UI
flutter run -d windows  # or -d chrome for web

# Terminal 2: Backend
npm run dev
```

## Configuration

### Environment Setup
Create a `.env` file in the project root:
```env
# API Configuration
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
# Server Configuration
SERVER_HOST=localhost
SERVER_PORT=3000
# Database Configuration
DATABASE_URL=your_database_url
# OAuth Configuration
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
```

### Local AI Setup
To use local AI models with Ollama:
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
# Download models
ollama pull llama3.2:1b
ollama pull codellama:7b
ollama pull mistral:7b
```

## Testing

1. Run Flutter tests:
```bash
flutter test
```

2. Run Node.js tests:
```bash
npm test
```

3. Run E2E tests:
```bash
npx playwright test
```

## Common Tasks

### Running the Application
```bash
# Start backend
npm run dev

# Start Flutter app
flutter run -d windows  # or -d chrome for web
```

### Building for Production
```bash
# Build Flutter app
flutter build windows  # or web/linux/macos

# Build backend
npm run build
```

## Next Steps

- [Development Workflow](../DEVELOPMENT/WORKFLOW.md)
- [Architecture Overview](../ARCHITECTURE/README.md)
- [Deployment Guide](../DEPLOYMENT/README.md)