#!/usr/bin/env node

/**
 * Securely store the Linear API key for local development without committing it.
 *
 * This script writes/updates a local .env file in the project root with:
 *   LINEAR_API_KEY=... 
 *
 * Usage:
 *   - node scripts/setup-linear-key.js --set "<your_linear_api_key_here>"
 *   - or provide via env var: LINEAR_API_KEY=... node scripts/setup-linear-key.js
 *
 * Notes:
 *   - .env files are already gitignored by this repo (.gitignore has .env*).
 *   - Do NOT commit secrets to source control.
 */

const fs = require('fs');
const path = require('path');

function upsertEnvVar(filePath, key, value) {
  let content = '';
  if (fs.existsSync(filePath)) {
    content = fs.readFileSync(filePath, 'utf8');
  }

  const lines = content.split(/\r?\n/);
  let found = false;
  const newLines = lines.map((line) => {
    // Preserve comments and empty lines
    if (/^\s*#/.test(line) || /^\s*$/.test(line)) return line;
    const [k] = line.split('=');
    if (k === key) {
      found = true;
      return `${key}=${value}`;
    }
    return line;
  });

  if (!found) newLines.push(`${key}=${value}`);

  const finalContent = newLines.filter((l, idx, arr) => !(idx === arr.length - 1 && l.trim() === '' ))
    .join('\n') + '\n';
  fs.writeFileSync(filePath, finalContent, { encoding: 'utf8', mode: 0o600 });
}

(function main() {
  const args = process.argv.slice(2);
  const setIdx = args.indexOf('--set');
  const provided = setIdx !== -1 ? args[setIdx + 1] : undefined;
  const token = provided || process.env.LINEAR_API_KEY;

  if (!token) {
    console.error('Usage: node scripts/setup-linear-key.js --set "<your_linear_api_key_here>"');
    console.error('       or: LINEAR_API_KEY=... node scripts/setup-linear-key.js');
    process.exit(1);
  }

  const projectRoot = path.resolve(__dirname, '..');
  const dotEnvPath = path.join(projectRoot, '.env');

  // Minimal validation: Linear tokens often start with "lin_api_"
  if (!/^lin_api_/i.test(token)) {
    console.warn('[setup-linear-key] Warning: The provided token does not look like a Linear token (expected to start with "lin_api_"). Proceeding anyway.');
  }

  upsertEnvVar(dotEnvPath, 'LINEAR_API_KEY', token);

  console.log(`\n✅ Saved LINEAR_API_KEY to ${dotEnvPath} (file mode 600).`);
  console.log('\nNext steps:');
  console.log('- Keep this file private. It is gitignored.');
  console.log('- When running an MCP-enabled client or tools that require Linear, ensure the env is loaded, e.g.:');
  console.log('    export $(grep -v "^#" .env | xargs) && <your-mcp-client-command>');
  console.log('  or:');
  console.log('    set -a; source .env; set +a; <your-mcp-client-command>');
  console.log('\nIf you have not yet generated the MCP config, run:');
  console.log('    npm run setup:mcp');
})();
