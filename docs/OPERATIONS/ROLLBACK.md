# Rollback Procedures

This document outlines the procedures for rolling back deployments in the CloudToLocalLLM environment.

## Overview

We use Argo CD for GitOps-based deployments. Rollbacks can be performed by reverting the Git commit that introduced the failing change, or by temporarily using the Argo CD UI/CLI to rollback to a previous state (though Git reversion is preferred for persistence).

## Procedure 1: Git Revert (Preferred)

This method ensures that the state in Git matches the state in the cluster.

1.  **Identify the Bad Commit**:
    ```bash
    git log
    ```
    Find the SHA of the commit that caused the issue.

2.  **Revert the Commit**:
    ```bash
    git revert <COMMIT_SHA>
    git push origin main
    ```

3.  **Sync Argo CD**:
    Argo CD should automatically detect the change and sync (since `automated` sync is enabled). If not:
    ```bash
    argocd app sync <APP_NAME>
    ```

## Procedure 2: Argo CD Rollback (Emergency)

Use this if you need an immediate fix and cannot wait for the Git pipeline. **Note:** Self-healing must be temporarily disabled or it will immediately revert your manual rollback.

1.  **Disable Self-Healing**:
    ```bash
    argocd app set <APP_NAME> --self-heal=false
    ```

2.  **List History**:
    ```bash
    argocd app history <APP_NAME>
    ```

3.  **Rollback**:
    ```bash
    argocd app rollback <APP_NAME> <HISTORY_ID>
    ```

4.  **Restore State in Git**:
    You must still perform **Procedure 1** to ensure the repository matches the cluster state. Once fixed in Git:

5.  **Re-enable Self-Healing**:
    ```bash
    argocd app set <APP_NAME> --self-heal=true
    ```

## Procedure 3: Manual Image Rollback

If the manifest hasn't changed but the image is bad:

1.  **Find Previous Image Tag**: Check container registry or previous Git commits.
2.  **Update Manifest**:
    Edit `kustomization.yaml` to point to the previous working image tag.
3.  **Commit and Push**:
    ```bash
    git commit -am "fix: rollback image to <OLD_TAG>"
    git push origin main
    ```
