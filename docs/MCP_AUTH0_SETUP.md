# Auth0 MCP Server Setup Guide

## Overview
The Auth0 MCP server allows you to manage your Auth0 tenant configuration through Kiro IDE. However, it requires proper authentication credentials to function.

## Current Status
- **Status**: Disabled (to prevent error logs)
- **Reason**: Missing `AUTH0_CLIENT_SECRET` configuration

## Setup Instructions

### 1. Get Your Auth0 Credentials
You need to obtain the client secret from your Auth0 application:

1. Go to [Auth0 Dashboard](https://manage.auth0.com/)
2. Navigate to Applications
3. Find your application: `FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A`
4. Copy the **Client Secret**

### 2. Configure Credentials Securely

#### Option A: Environment File (Recommended)
1. Copy `.env.mcp` to `.env.mcp.local`:
   ```bash
   copy .env.mcp .env.mcp.local
   ```

2. Edit `.env.mcp.local` and add your actual client secret:
   ```env
   AUTH0_DOMAIN=dev-v2f2p008x3dr74ww.us.auth0.com
   AUTH0_CLIENT_ID=FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A
   AUTH0_CLIENT_SECRET=your_actual_client_secret_here
   ```

3. Update `.kiro/settings/mcp.json` to use environment variables:
   ```json
   "auth0": {
     "command": "npx",
     "args": ["@auth0/auth0-mcp-server", "run"],
     "env": {
       "FASTMCP_LOG_LEVEL": "ERROR",
       "AUTH0_DOMAIN": "${AUTH0_DOMAIN}",
       "AUTH0_CLIENT_ID": "${AUTH0_CLIENT_ID}",
       "AUTH0_CLIENT_SECRET": "${AUTH0_CLIENT_SECRET}"
     },
     "disabled": false
   }
   ```

#### Option B: Direct Configuration (Less Secure)
Directly edit `.kiro/settings/mcp.json` and add your client secret:
```json
"AUTH0_CLIENT_SECRET": "your_actual_client_secret_here"
```

### 3. Enable the Server
Set `"disabled": false` in the auth0 server configuration in `.kiro/settings/mcp.json`.

### 4. Required Auth0 Scopes
The MCP server needs specific scopes to function. Ensure your Auth0 application has:
- `read:resource_servers`
- `read:applications` (for expanded functionality)
- `create:applications` (for creation operations)

## Available Functions
Once configured, you'll have access to:
- `mcp_auth0_auth0_list_resource_servers` ✅ (currently working)
- `mcp_auth0_auth0_get_application` (requires additional scopes)
- `mcp_auth0_auth0_create_application` (requires additional scopes)

## Security Notes
- Never commit `.env.mcp.local` to version control
- The file is already added to `.gitignore`
- Consider using environment variables in production
- Rotate client secrets regularly

## Troubleshooting
- **"Invalid Auth0 configuration"**: Missing or incorrect client secret
- **Permission errors**: Check Auth0 application scopes
- **Connection timeout**: Verify domain and client ID are correct