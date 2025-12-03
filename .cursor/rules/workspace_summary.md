# CloudToLocalLLM Workspace Rules & Constraints

## Critical Directives
1. **Docker & Flutter**:
   - **NEVER** run Flutter as root. Always switch to `USER 1000:1000` (or container default) *before* any `flutter` command.
   - Use `COPY` instead of `git clone`.
   - Layer caching: Copy `pubspec.yaml`/`lock` first, run `flutter pub get`, then copy source.

2. **Node.js**:
   - Production: `npm ci`. Development: `npm install`.
   - Never manually edit `package-lock.json`.
   - Docker: Run as non-root (UID 1001).

3. **Workflow**:
   - **MCP**: Use `task_progress` for complex tasks. Atomic tool calls.
   - **Testing**: Fix linter errors before committing.
   - **Versioning**: Strict Semantic Versioning (Patch/Minor/Major).

4. **Communication**:
   - Concise, direct, no decorative formatting.

## Tool Locations (Local Environment)
- **Flutter SDK**: `/home/rightguy/development/flutter/` (v3.38.3)
- **Cloudflared**: `/usr/local/bin/cloudflared` (v2025.11.1)
- **MCP Tools**: `/home/rightguy/development/mcp-tools/`
- **CLI Tools**: `psql` (v17), `yq` (v4), `k6` (v1.4), `supabase` (v2.65), `az` (v2.81)
