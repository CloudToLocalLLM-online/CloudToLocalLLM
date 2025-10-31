#!/usr/bin/env node

/**
 * Auth0 MCP Server
 * Manages Auth0 tenant configuration, users, and applications
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';

const server = new Server(
  {
    name: 'auth0-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper to execute auth0 CLI commands
function executeAuth0Command(command) {
  try {
    const output = execSync(`auth0 ${command}`, { encoding: 'utf-8' });
    return { success: true, output };
  } catch (error) {
    return { success: false, error: error.message, output: error.stdout };
  }
}

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'auth0_list_applications',
        description: 'List all Auth0 applications in your tenant',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'auth0_create_application',
        description: 'Create a new Auth0 application',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Application name' },
            type: { 
              type: 'string', 
              enum: ['spa', 'regular', 'native', 'm2m'],
              description: 'Application type' 
            },
            callbacks: { 
              type: 'string', 
              description: 'Comma-separated callback URLs' 
            },
            origins: { 
              type: 'string', 
              description: 'Comma-separated allowed origins' 
            },
          },
          required: ['name', 'type'],
        },
      },
      {
        name: 'auth0_get_application',
        description: 'Get Auth0 application details',
        inputSchema: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'Application ID or name' },
          },
          required: ['id'],
        },
      },
      {
        name: 'auth0_update_application',
        description: 'Update Auth0 application configuration',
        inputSchema: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'Application ID' },
            callbacks: { type: 'string', description: 'Callback URLs' },
            origins: { type: 'string', description: 'Allowed origins' },
            logout_urls: { type: 'string', description: 'Logout URLs' },
          },
          required: ['id'],
        },
      },
      {
        name: 'auth0_list_users',
        description: 'List Auth0 users',
        inputSchema: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query' },
            limit: { type: 'number', description: 'Max results (default 50)' },
          },
        },
      },
      {
        name: 'auth0_create_user',
        description: 'Create a new Auth0 user',
        inputSchema: {
          type: 'object',
          properties: {
            email: { type: 'string', description: 'User email' },
            password: { type: 'string', description: 'User password' },
            connection: { 
              type: 'string', 
              description: 'Connection name (default: Username-Password-Authentication)' 
            },
          },
          required: ['email', 'password'],
        },
      },
      {
        name: 'auth0_enable_social_connection',
        description: 'Enable social login provider (Google, GitHub, etc.)',
        inputSchema: {
          type: 'object',
          properties: {
            provider: { 
              type: 'string',
              enum: ['google-oauth2', 'github', 'facebook', 'twitter', 'linkedin'],
              description: 'Social provider' 
            },
            client_id: { type: 'string', description: 'Provider client ID (optional for dev keys)' },
            client_secret: { type: 'string', description: 'Provider client secret (optional for dev keys)' },
          },
          required: ['provider'],
        },
      },
      {
        name: 'auth0_list_connections',
        description: 'List all Auth0 connections (database, social, enterprise)',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'auth0_tenant_info',
        description: 'Get current Auth0 tenant information',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'auth0_list_apis',
        description: 'List all Auth0 APIs (Resource Servers)',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'auth0_get_api',
        description: 'Get Auth0 API details by identifier',
        inputSchema: {
          type: 'object',
          properties: {
            identifier: { type: 'string', description: 'API identifier' },
          },
          required: ['identifier'],
        },
      },
    ],
  };
});

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'auth0_list_applications':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command('apps list --json'), null, 2),
            },
          ],
        };

      case 'auth0_create_application':
        const createCmd = [
          'apps create',
          `--name "${args.name}"`,
          `--type ${args.type}`,
          args.callbacks ? `--callbacks "${args.callbacks}"` : '',
          args.origins ? `--origins "${args.origins}"` : '',
          '--json',
        ].filter(Boolean).join(' ');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(createCmd), null, 2),
            },
          ],
        };

      case 'auth0_get_application':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(`apps show ${args.id} --json`), null, 2),
            },
          ],
        };

      case 'auth0_update_application':
        const updateCmd = [
          `apps update ${args.id}`,
          args.callbacks ? `--callbacks "${args.callbacks}"` : '',
          args.origins ? `--origins "${args.origins}"` : '',
          args.logout_urls ? `--logout-urls "${args.logout_urls}"` : '',
          '--json',
        ].filter(Boolean).join(' ');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(updateCmd), null, 2),
            },
          ],
        };

      case 'auth0_list_users':
        const listUsersCmd = [
          'users list',
          args.query ? `--query "${args.query}"` : '',
          args.limit ? `--number ${args.limit}` : '',
          '--json',
        ].filter(Boolean).join(' ');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(listUsersCmd), null, 2),
            },
          ],
        };

      case 'auth0_create_user':
        const createUserCmd = [
          'users create',
          `--email "${args.email}"`,
          `--password "${args.password}"`,
          `--connection "${args.connection || 'Username-Password-Authentication'}"`,
          '--json',
        ].join(' ');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(createUserCmd), null, 2),
            },
          ],
        };

      case 'auth0_enable_social_connection':
        // Note: Full social connection setup requires Management API
        // This provides guidance on using Auth0 Dashboard
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                success: true,
                message: `To enable ${args.provider}:
1. Go to Auth0 Dashboard > Authentication > Social
2. Click ${args.provider}
3. Toggle "Use Auth0 developer keys" for testing (no client ID/secret needed)
4. Or add your own client ID/secret: ${args.client_id || 'Not provided'}
5. Enable applications that should use this connection
6. Save changes

Callback URL: https://YOUR_TENANT.auth0.com/login/callback
`,
                provider: args.provider,
                dashboard_url: 'https://manage.auth0.com/dashboard',
              }, null, 2),
            },
          ],
        };

      case 'auth0_list_connections':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command('api get connections --json'), null, 2),
            },
          ],
        };

      case 'auth0_tenant_info':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command('tenants list --json'), null, 2),
            },
          ],
        };

      case 'auth0_list_apis':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command('apis list --json'), null, 2),
            },
          ],
        };

      case 'auth0_get_api':
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(executeAuth0Command(`apis show ${args.identifier} --json`), null, 2),
            },
          ],
        };

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({ error: error.message }, null, 2),
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Auth0 MCP server running on stdio');
}

main().catch(console.error);

