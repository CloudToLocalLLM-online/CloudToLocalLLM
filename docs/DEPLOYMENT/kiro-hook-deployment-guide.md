# Kiro Hook Deployment Guide

This guide explains how to set up and use Kiro hooks for automated CloudToLocalLLM deployment. Kiro hooks provide a convenient way to trigger deployments directly from the IDE with customizable parameters.

## Overview

Kiro hooks allow you to execute the CloudToLocalLLM deployment workflow with a simple click, without having to manually run PowerShell commands. The hooks are configured to:

- Provide a user-friendly interface for deployment parameters
- Execute the deployment script with proper arguments
- Display real-time progress and status updates
- Notify you of deployment success or failure

## Available Deployment Hooks

CloudToLocalLLM includes several pre-configured deployment hooks:

1. **Automated Deployment Workflow** - Full production deployment with version increment
2. **Staging Deployment** - Deployment to staging environment for testing
3. **Deployment Dry Run** - Preview deployment actions without executing changes

## Using Deployment Hooks

### Triggering a Deployment

To trigger a deployment using a Kiro hook:

1. Open the Kiro panel in your IDE
2. Navigate to the "Agent Hooks" section
3. Find the desired deployment hook (e.g., "Automated Deployment Workflow")
4. Click the "Run" button next to the hook
5. Configure the deployment parameters in the dialog:
   - Select the target environment (Production, Staging, Local)
   - Choose the version increment type (build, patch, minor, major)
6. Click "Execute" to start the deployment
7. Monitor the progress in the Kiro output panel

### Monitoring Deployment Progress

The hook execution will show real-time progress with color-coded messages:

- **Green** - Success messages and completed phases
- **Blue** - Informational messages
- **Yellow** - Warnings
- **Red** - Errors
- **Magenta** - Phase transitions
- **Cyan** - Step indicators

A progress bar will also show the overall deployment progress.

### Deployment Notifications

The hook will provide notifications at key points:

- **Start** - When the deployment begins
- **Success** - When the deployment completes successfully
- **Failure** - If the deployment encounters errors

## Creating Custom Deployment Hooks

You can create custom deployment hooks for specific deployment scenarios.

### Basic Hook Structure

Kiro hooks are defined in JSON files with the `.kiro.hook` extension in the `.kiro/hooks/` directory. A basic deployment hook structure looks like:

```json
{
  "enabled": true,
  "name": "Custom Deployment Hook",
  "description": "Custom deployment configuration for specific scenarios",
  "version": "1.0.0",
  "when": {
    "type": "manual",
    "displayName": "Custom Deploy",
    "icon": "rocket",
    "category": "Deployment"
  },
  "then": {
    "type": "executeScript",
    "script": {
      "command": "powershell.exe",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-NoProfile",
        "-File",
        "scripts/powershell/Deploy-CloudToLocalLLM.ps1",
        "-Environment",
        "{{environment}}",
        "-VersionIncrement",
        "{{versionIncrement}}",
        "-Force"
      ],
      "workingDirectory": ".",
      "timeout": 1800
    },
    "parameters": [
      {
        "name": "environment",
        "displayName": "Deployment Environment",
        "type": "select",
        "required": true,
        "default": "Staging",
        "options": [
          {
            "label": "Production",
            "value": "Production"
          },
          {
            "label": "Staging",
            "value": "Staging"
          }
        ]
      },
      {
        "name": "versionIncrement",
        "displayName": "Version Increment",
        "type": "select",
        "required": true,
        "default": "build",
        "options": [
          {
            "label": "Build",
            "value": "build"
          },
          {
            "label": "Patch",
            "value": "patch"
          }
        ]
      }
    ]
  }
}
```

### Creating a New Hook

To create a new deployment hook:

1. Create a new file in `.kiro/hooks/` with the `.kiro.hook` extension
2. Define the hook structure as shown above
3. Customize the parameters and script arguments
4. Save the file and refresh the Kiro panel

### Hook Parameters

You can customize the parameters available in the hook:

- **Select Parameters** - Dropdown menus for options like environment or version increment
- **Text Parameters** - Free text input for custom values
- **Boolean Parameters** - Checkboxes for toggle options

Example parameter configuration:

```json
{
  "name": "skipVerification",
  "displayName": "Skip Verification",
  "description": "Skip post-deployment verification steps",
  "type": "boolean",
  "required": false,
  "default": false
}
```

### Output Handling

Configure how the hook displays output from the deployment script:

```json
"outputHandling": {
  "streamOutput": true,
  "captureStdout": true,
  "captureStderr": true,
  "logLevel": "info",
  "progressIndicators": [
    {
      "pattern": "\\[INFO\\]\\s+(.+)",
      "type": "info",
      "extractMessage": true
    },
    {
      "pattern": "Progress:\\s+(\\d+)%",
      "type": "progress",
      "extractProgress": true
    }
  ]
}
```

### Error Handling

Configure how the hook handles deployment errors:

```json
"errorHandling": {
  "retryCount": 0,
  "retryDelay": 0,
  "failureActions": [
    {
      "condition": "exitCode != 0",
      "action": "showError",
      "message": "Deployment failed. Check the output for details."
    }
  ]
}
```

## Hook Requirements

Specify the requirements for the hook to function properly:

```json
"requirements": {
  "platform": ["windows"],
  "dependencies": [
    {
      "name": "PowerShell",
      "version": ">=5.1"
    },
    {
      "name": "WSL2",
      "description": "Windows Subsystem for Linux 2 with Ubuntu 24.04"
    }
  ]
}
```

## Best Practices

### Hook Naming and Organization

- Use descriptive names for hooks (e.g., "Production Deployment", "Staging Deployment")
- Include the target environment in the hook name
- Group related hooks using consistent categories

### Parameter Configuration

- Provide sensible defaults for parameters
- Include descriptions for all parameters
- Limit options to valid choices
- Use appropriate parameter types (select, text, boolean)

### Timeout and Error Handling

- Set appropriate timeouts based on deployment complexity
- Configure error handling to provide useful feedback
- Include retry logic for transient failures
- Provide clear error messages

### Notifications

- Enable notifications for long-running deployments
- Include relevant information in notification messages
- Use different notification types for different events

## Troubleshooting

### Common Hook Issues

| Issue | Solution |
|-------|----------|
| Hook not appearing in Kiro panel | Ensure the hook file has the `.kiro.hook` extension and is in the `.kiro/hooks/` directory |
| Hook execution fails immediately | Check that the script path and command are correct |
| Parameters not working | Verify parameter names match the placeholders in the script arguments |
| Progress not showing | Check that the output handling configuration matches the script output patterns |

### Debugging Hooks

To debug a hook execution:

1. Enable verbose logging in the hook configuration
2. Check the hook execution logs in the Kiro output panel
3. Verify the command being executed matches what you would run manually
4. Try running the same command manually to see if it works

## Further Reading

- [Automated Deployment Workflow](./automated-deployment-workflow.md)
- [Kiro Hook System Documentation](../DEVELOPMENT/kiro-hooks.md)
- [Deployment Troubleshooting Guide](./deployment-troubleshooting.md)