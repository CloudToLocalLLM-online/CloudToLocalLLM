---
type: "always_apply"
description: "MCP/Tools Usage Rules for CloudToLocalLLM"
---

## Tool Selection Rules
- Prefer minimal, high-signal tool calls. Each call must have a clear purpose and next action.
- Always confirm function/class/file existence before editing.

## Codebase Navigation
- view (file/directory): when you know the path or need to open a file. Use search_query_regex to find symbol usages within a file.
- grep-search/codebase-retrieval: use when you don’t know the exact file(s). Constrain queries and avoid repeated broad searches.
- git-commit-retrieval: use to learn prior approaches/rationales from history. Verify against current code afterward.

## Editing Files
- Use str-replace-editor exclusively for modifications; do not recreate files wholesale.
- Gather exact old_str ranges before editing. Keep edits under 150 lines per call.
- Respect existing code style; make the smallest safe change.

### Example: Renaming a function
1. **Identify the function to rename:** `old_function_name`
2. **Find the file containing the function:** `lib/utils.dart`
3. **Use `str-replace-editor` to perform the rename:**
   ```
   <tool_code>
   print(default_api.replace(
       file_path='/home/rightguy/dev/CloudToLocalLLM/lib/utils.dart',
       old_string='void old_function_name() {',
       new_string='void new_function_name() {'
   ))
   </tool_code>
   ```

## Dependency Management
- Never hand-edit package manifests or lockfiles. Use proper package managers (npm/yarn/pnpm, flutter pub, etc.).

## Processes and Verification
- Use launch-process for builds/tests/linters; summarize commands, cwd, exit codes, and key output.
- Safe-by-default runs are encouraged after changes (tests, lint, small builds). Avoid destructive or costly operations without approval.

## GitHub API Usage
- Scope all queries to imrightguy/CloudToLocalLLM unless explicitly requested otherwise.
- Before creating PRs or pushing, ask for permission. When checking CI, use commit status/check-runs endpoints.

## Secrets and Safety
- Never print secret values. Use environment variables and secret stores (GitHub Secrets, GCP Secret Manager).
- Do not hardcode secrets in source. Replace legacy keys with runtime injection via CI/CD.

## Communication
- Start non-trivial work with a short plan and a tasklist.
- Explain notable actions; keep messages concise and skimmable. Wrap code excerpts in <augment_code_snippet> tags with path and mode.

## Architecture-Specific Notes
- GCIP API key must be injected at runtime into cloudrun-config.js by docker-entrypoint-web.sh. Ensure workflows pass GCIP_API_KEY to the web service.
- For the API, pass DB_* and CLOUD_SQL_CONNECTION_NAME via Cloud Run env vars and attach Cloud SQL instances as needed.

## Additional Tools

### Sequential Thinking (sequentialthinking_Sequential_thinking)
Use for complex, multi-step problem solving when:
- Planning deployments or migrations with several dependent steps
- Designing cross-service changes (web, API, streaming, CI/CD)
- Triaging ambiguous production incidents
Guidelines:
- Start with a brief hypothesis and total_thoughts estimate; revise as you learn
- Keep thoughts focused on the next concrete action; cut branches that don’t add value
- Conclude with a clear solution hypothesis and verification plan

### Context7 Library Docs (resolve-library-id_Context_7 + get-library-docs_Context_7)
Use to retrieve authoritative docs/snippets for popular libraries (e.g., Next.js, Firebase, Supabase) when:
- You need up-to-date API references for implementation decisions
- You want examples for a specific topic (e.g., hooks, routing, auth)
Guidelines:
- Always call resolve-library-id_Context_7 first to get the Context7-compatible ID
- Then call get-library-docs_Context_7 with a focused topic and reasonable token limit
- Summarize and cite what’s relevant; don’t paste large dumps

### Playwright Browser Tools (browser_* namespace)
Use for web automation/testing when you need to:
- Navigate to deployed environments and validate behavior (e.g., GCIP login flow)
- Capture console logs, network requests, screenshots, and accessibility snapshots
- Simulate user actions: click, type, select, submit
Guidelines:
- Install the browser via browser_install_Playwright if needed
- Prefer lightweight checks first (console logs, specific network calls) before full E2E
- Avoid interacting with production data destructively; read-only validations are preferred
- Capture key evidence: exit codes, notable console messages, HTTP status codes

