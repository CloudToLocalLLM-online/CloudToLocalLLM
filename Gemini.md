# Gemini Protocol & Repository Governance

This document defines the mandatory operational protocols for AI Agents (Gemini, Kilocode, etc.) interacting with this repository.

## 🛡️ Root Directory Preservation Protocol (RDPP)

**Status:** MANDATORY / ZERO TOLERANCE

To maintain repository integrity and reduce cognitive load, a strict "clean-root" policy is enforced.

### 1. Prohibited Actions
- **DO NOT** create new files in the repository root (`/`).
- **DO NOT** create new directories in the repository root without explicit architectural approval.
- **DO NOT** leave temporary files, logs, or "orphan" markdown files in the root.

### 2. Permitted Files (Whitelist)
Only the following files are permitted to reside in the repository root:
- **Essential Toolchain Configurations:** `.gitignore`, `.gitattributes`, `LICENSE`, `package.json`, `pubspec.yaml`, `Makefile`, `docker-compose.yml`, `playwright.config.js`.
- **Project Entry Points:** `README.md`.
- **Agent Instructions:** `Gemini.md`, `.kiro/` (steering), `.cursor/` (rules).

### 3. Migration Directive
If an operation generates a file that would normally reside in the root, it **MUST** be redirected to an appropriate subdirectory:
- **Documentation:** `docs/` (following the domain-driven taxonomy).
- **Configurations:** `config/` or `infra/`.
- **Scripts:** `scripts/`.
- **Binaries/Tools:** `build-tools/` or `bin/`.

## 📚 Single Source of Truth (SSOT)

- All documentation must be centralized in the `docs/` directory.
- Avoid duplicate documentation. Merge overlapping content into the most relevant authoritative file.
- Use relative cross-linking between documents to maintain a navigable knowledge graph.

## 🤖 Agent Context

For comprehensive operating instructions, refer to [`docs/development/AGENT_CONTEXT.md`](docs/development/AGENT_CONTEXT.md).
