#!/usr/bin/env node

/**
 * Test script to interact with Auth0 MCP server
 */

import { spawn } from 'child_process';
import { createInterface } from 'readline';

async function testAuth0MCP() {
  console.log('🧪 Testing Auth0 MCP Server...');
  
  try {
    // Start the Auth0 MCP server
    const mcpServer = spawn('npx', ['-y', '@auth0/auth0-mcp-server', 'run', '--tools', 'auth0_*_resource_servers'], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    console.log('📡 Auth0 MCP Server started...');

    // Send MCP protocol messages
    const initMessage = {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {}
        },
        clientInfo: {
          name: "auth0-config-script",
          version: "1.0.0"
        }
      }
    };

    console.log('📤 Sending initialize message...');
    mcpServer.stdin.write(JSON.stringify(initMessage) + '\n');

    // Listen for responses
    mcpServer.stdout.on('data', (data) => {
      const response = data.toString();
      console.log('📥 MCP Response:', response);
      
      // If we get a successful initialize response, try to list resource servers
      if (response.includes('"result"')) {
        const listMessage = {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: {
            name: "auth0_list_resource_servers",
            arguments: {}
          }
        };
        
        console.log('📤 Sending list resource servers request...');
        mcpServer.stdin.write(JSON.stringify(listMessage) + '\n');
      }
    });

    mcpServer.stderr.on('data', (data) => {
      console.log('🔍 MCP Debug:', data.toString());
    });

    mcpServer.on('close', (code) => {
      console.log(`🔚 MCP Server exited with code ${code}`);
    });

    // Keep the process alive for a bit
    setTimeout(() => {
      console.log('⏰ Closing MCP server...');
      mcpServer.kill();
    }, 10000);

  } catch (error) {
    console.error('❌ Error testing Auth0 MCP:', error.message);
  }
}

testAuth0MCP();
