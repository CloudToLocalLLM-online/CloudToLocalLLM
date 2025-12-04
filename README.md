# CloudToLocalLLM

Run powerful LLMs locally with an optional cloud relay – privacy-first, cross‑platform, and in active development.

> **Status:** Heavy development/early access. Premium cloud features are planned and not yet available.

## Who this is for
- Individuals who want to run LLMs locally for free (self-install).
- Businesses that want to self-host; commercial use requires a paid license.
- Users who may later opt into cloud relay/premium features (separate from self-install).

## What you get (today)
- Local AI control: Connect to your own Ollama models; keep data on your machine.
- Optional cloud path: Cloud relay planned; premium features will be separate from self-install.
- Cross-platform: Windows, Linux, and web today; macOS in progress.
- Privacy-first: Local by default; cloud usage is opt-in.
- Modern UI: Tray integration on desktop, streaming chat experience, and responsive web experience.

## Licensing & plans
- **Self-install:** Free for personal use. Business use requires a paid license.
- **Cloud premium:** Separate from self-install; planned but not yet live.
- **Business inquiries:** Use GitHub Issues/Discussions to reach out about licensing while we finalize premium options.

## How it works
- **Local path (default):** The desktop/web app talks to your local Ollama at `http://localhost:11434` (configurable). Data stays on your device.
- **Cloud path (planned):** When enabled, you’ll be able to sign in and route through our cloud relay for remote access and premium features. This is separate from the self-install license.

## Requirements
- Ollama installed and at least one model pulled (e.g., `ollama pull llama3.2`).
- OS: Windows or Linux today; macOS support is in progress.
- Network: Needed for downloads/sign-in/cloud relay; local-only use can stay offline after setup.

## Quick start (local mode)
1) Download the latest release for your platform: [GitHub Releases](https://github.com/imrightguy/CloudToLocalLLM/releases/latest).  
2) Install Ollama and pull a model (e.g., `ollama pull llama3.2`).  
3) Launch CloudToLocalLLM.  
4) Point the app to your local Ollama instance (defaults: `http://localhost:11434`).  
5) Use it locally without cloud. Optional: sign in when cloud relay/premium goes live; stay local-only if you prefer.

Platform-specific install steps and troubleshooting: `docs/INSTALLATION/README.md` (Windows/Linux today; macOS coming soon).

## Cloud & premium (separate from self-install)
- Cloud relay and premium features are planned but not yet available.
- When live, business users will need a paid plan; personal self-install remains free.

## Privacy & data
- Local by default: requests to your local Ollama stay on your device.
- Cloud use (when enabled) may send data through our API endpoints.
- Auth uses Supabase; error reporting uses Sentry by default. You can disable/override these in settings/config if you prefer local-only.
- Running offline keeps traffic local; if you’re online and want zero telemetry, turn off Sentry/analytics in settings or via config before running.

## Support & docs
- User guides and troubleshooting: `docs/USER_DOCUMENTATION/`
- Install help: `docs/INSTALLATION/`
- Issues & questions: open a GitHub Issue or Discussion on the repo.

For development, architecture, backend documentation, and CI details, see `docs/README.md`. This README is focused on customers using the app.
# AI-Powered Versioning Active
