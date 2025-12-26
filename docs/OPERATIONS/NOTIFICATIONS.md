# Deployment Notifications

This document describes how to configure and manage notifications for deployment status.

## Argo CD Notifications

We use Argo CD Notifications to send alerts to external services (Slack, Email, etc.) when deployments succeed, fail, or degrade.

### Configuration

The configuration is managed in `k8s/argocd-config/argocd-notifications-cm.yaml` (or similar ConfigMap).

### Setup

1.  **Define Triggers**:
    Triggers determine *when* to send a notification.
    ```yaml
    trigger.on-sync-succeeded: |
      - description: Application syncing has succeeded
        send: [app-sync-succeeded]
        when: app.status.operationState.phase == 'Succeeded'
    ```

2.  **Define Templates**:
    Templates determine *what* the notification looks like.
    ```yaml
    template.app-sync-succeeded: |
      message: |
        Application {{.app.metadata.name}} has been successfully synced.
    ```

3.  **Configure Services**:
    To enable a service (e.g., Slack), you need to update the `argocd-notifications-secret` with your API token.

    **Slack Example:**
    ```bash
    kubectl patch secret argocd-notifications-secret -n argocd -p '{"stringData": {"slack-token": "<YOUR-SLACK-TOKEN>"}}'
    ```

### Integration with GitHub Actions

Our CI pipeline can also send notifications.

1.  **Slack**:
    Add the `rtCamp/action-slack-notify` step to `.github/workflows/deploy.yml`:
    ```yaml
    - name: Slack Notification
      uses: rtCamp/action-slack-notify@v2
      env:
        SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        SLACK_MESSAGE: 'Deployment Completed'
    ```

2.  **Email**:
    Use `dawidd6/action-send-mail` for email alerts.

## Current Status

Notifications are currently configured to alert on:
- Sync Failure
- Health Status Degraded
