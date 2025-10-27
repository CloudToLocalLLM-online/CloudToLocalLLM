# CloudToLocalLLM Installation Guide

This guide provides detailed installation instructions for all supported platforms.

## Windows Installation

### Prerequisites
- Windows 10/11
- Git for Windows
- Flutter SDK 3.8+
- Node.js 16/18+

### Steps
1. Clone the repository:
```powershell
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM
```

2. Install dependencies:
```powershell
flutter pub get
npm install
```

3. Setup environment:
- Copy `.env.example` to `.env`
- Configure your environment variables

## Linux Installation

### Prerequisites
- Git
- Flutter SDK 3.8+
- Node.js 16/18+

### Steps
1. Clone the repository:
```bash
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM
```

2. Install dependencies:
```bash
flutter pub get
npm install
```

3. Setup environment:
- Copy `.env.example` to `.env`
- Configure your environment variables

## macOS Installation

### Prerequisites
- Git
- Flutter SDK 3.8+
- Node.js 16/18+

### Steps
1. Clone the repository:
```bash
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM
```

2. Install dependencies:
```bash
flutter pub get
npm install
```

3. Setup environment:
- Copy `.env.example` to `.env`
- Configure your environment variables

## Docker Installation

### Prerequisites
- Docker and Docker Compose
- Git

### Steps
1. Clone the repository:
```bash
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM
```

2. Build and run with Docker Compose:
```bash
docker-compose up --build
```

## Next Steps
- [Quick Start Guide](QUICKSTART.md)
- [Configuration Guide](../DEVELOPMENT/GUIDES/CONFIGURATION.md)
- [Development Setup](../DEVELOPMENT/README.md)