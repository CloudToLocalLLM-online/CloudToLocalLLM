# Project Structure & Governance

## 🛡️ Root Directory Preservation Protocol (RDPP)
- **DO NOT** create new files in the repository root (`/`).
- **Permitted Files:** `.gitignore`, `LICENSE`, `package.json`, `pubspec.yaml`, `Gemini.md`, `README.md`.
- **Redirection:** All new assets must be placed in `docs/`, `config/`, `scripts/`, or `infra/` as appropriate.

## Key Directories
- `lib/` - Flutter app (main.dart, services/, widgets/)
- `services/` - Node.js backend (api-backend/, streaming-proxy/)
- `k8s/` - Kubernetes manifests
- `docs/` - Documentation (api/, architecture/, deployment/, development/, governance/, operations/, user-guide/)
- `.github/workflows/` - CI/CD (deploy.yml active, archive/ for old)

## Architecture Patterns
- **DI**: Services in `lib/di/locator.dart` using get_it
- **State**: Provider + ChangeNotifier pattern
- **Auth**: Auth0 OAuth → JWT → flutter_secure_storage
- **Routing**: go_router with auth guards

## Current Deployment
- **Cloud**: `deploy.yml` → Azure AKS
- **Domains**: cloudtolocalllm.online, app.*, api.*
- **Registry**: Azure ACR `imrightguycloudtolocalllm`