#!/usr/bin/env node

/**
 * Setup/merge MCP configuration for the Linear MCP server.
 *
 * This script writes to: ~/.junie/mcp/mcp.json
 * - It will create the directory/file if they do not exist.
 * - It will preserve existing servers and only add/update the "linear" entry.
 *
 * References:
 * - Model Context Protocol servers: https://github.com/modelcontextprotocol/servers
 * - Linear MCP docs: https://linear.app/docs/mcp
 */

import fs from 'fs';
import path from 'path';

function ensureDirSync(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function readJsonSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf8');
    if (!raw.trim()) return null;
    return JSON.parse(raw);
  } catch (e) {
    console.error(`[setup-mcp-config] Warning: Failed to parse existing JSON at ${filePath}. Will back it up and recreate. Error:`, e.message);
    // Backup the broken file
    try {
      const backup = `${filePath}.bak-${Date.now()}`;
      fs.copyFileSync(filePath, backup);
      console.error(`[setup-mcp-config] Backed up the original to: ${backup}`);
    } catch (e2) {
      console.error('[setup-mcp-config] Failed to backup original file:', e2.message);
    }
    return null;
  }
}

function writeJson(filePath, data) {
  const json = JSON.stringify(data, null, 2);
  fs.writeFileSync(filePath, json + '\n', 'utf8');
}

export function main() {
  const home = process.env.HOME || process.env.USERPROFILE;
  if (!home) {
    console.error('[setup-mcp-config] Could not determine HOME directory. Aborting.');
    process.exit(1);
  }

  const targetDir = path.join(home, '.junie', 'mcp');
  const targetFile = path.join(targetDir, 'mcp.json');

  ensureDirSync(targetDir);

  const existing = readJsonSafe(targetFile) || {};
  const config = { ...existing };

  // Ensure top-level container for servers is present.
  // Many MCP clients (e.g., Claude Desktop style) use different shapes;
  // We will adopt a generic shape that is commonly supported by Junie-like clients:
  // {
  //   "mcpServers": {
  //     "linear": { "command": "npx", "args": ["-y", "@linear/mcp-server"], "env": { "LINEAR_API_KEY": "${LINEAR_API_KEY}" } }
  //   }
  // }
  if (!config.mcpServers || typeof config.mcpServers !== 'object') {
    config.mcpServers = {};
  }

  // Add/Update Linear MCP server entry
  const linearEntry = {
    command: 'npx',
    args: ['-y', '@linear/mcp-server'],
    env: {
      // Use env passthrough. The actual value should be provided by the environment at runtime.
      LINEAR_API_KEY: '${LINEAR_API_KEY}'
    }
  };

  config.mcpServers.linear = linearEntry;

  // Optionally, we could include a comment-like field with references (JSON has no comments)
  config._mcp_references = config._mcp_references || {};
  config._mcp_references.linear = {
    docs: 'https://linear.app/docs/mcp',
    registry: 'https://github.com/modelcontextprotocol/servers'
  };

  writeJson(targetFile, config);

  const needsApiKey = !process.env.LINEAR_API_KEY;

  console.log('\n✅ MCP configuration updated at:', targetFile);
  console.log('\nAdded/updated entry: mcpServers.linear');
  console.log('\nTo use the Linear MCP server, ensure your environment includes LINEAR_API_KEY.');
  console.log('You can set it temporarily when starting your MCP-enabled client, e.g.:');
  console.log('\n  LINEAR_API_KEY=your_linear_token_here <your-mcp-client-command>\n');
  console.log('References:');
  console.log('- MCP Servers Registry: https://github.com/modelcontextprotocol/servers');
  console.log('- Linear MCP Docs:      https://linear.app/docs/mcp');

  if (needsApiKey) {
    console.log('\n⚠️  LINEAR_API_KEY is not currently set in your environment.');
  }
}

if (import.meta.url.startsWith('file:') && process.argv[1] === new URL(import.meta.url).pathname) {
  main();
}