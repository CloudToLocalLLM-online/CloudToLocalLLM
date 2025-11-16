#!/usr/bin/env node

/**
 * Docker MCP Wrapper for Windows
 * This wrapper ensures DOCKER_HOST is properly set for Windows named pipes
 */

const { spawn } = require('child_process');
const path = require('path');

// Set Docker host for Windows
process.env.DOCKER_HOST = 'npipe:////./pipe/docker_engine';

// Get npx path
const npxCommand = process.platform === 'win32' ? 'npx.cmd' : 'npx';

// Spawn docker-mcp with proper environment
const child = spawn(npxCommand, ['-y', 'docker-mcp'], {
  stdio: 'inherit',
  env: {
    ...process.env,
    DOCKER_HOST: 'npipe:////./pipe/docker_engine'
  },
  shell: true
});

child.on('error', (error) => {
  console.error('Failed to start docker-mcp:', error);
  process.exit(1);
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
