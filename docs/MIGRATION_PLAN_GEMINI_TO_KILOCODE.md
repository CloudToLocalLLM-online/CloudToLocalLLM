# Migration Plan: geminicli to kilocodecli

## Overview
This document outlines the comprehensive plan to transition the project's AI-powered versioning and analysis tools from the existing `geminicli` (implemented as `scripts/gemini-cli.cjs`) to the new `kilocodecli`. The goal is to maintain seamless access to the Gemini API while adopting the new CLI standard.

## 1. Installation of kilocodecli

The `kilocodecli` will be implemented as a robust Node.js script, replacing the functionality of `gemini-cli.cjs`.

### Steps:
1.  **Create `scripts/kilocode-cli.cjs`**:
    -   This script will serve as the new entry point for AI operations.
    -   It will accept prompts and return JSON-formatted responses, preserving the interface expected by consuming scripts.
    -   It will be enhanced to support `KILOCODE_API_KEY` while maintaining backward compatibility or migration paths for `GEMINI_API_KEY`.

2.  **Make Executable**:
    -   Ensure the script has the correct permissions (`chmod +x`).

## 2. Secure Configuration

We will transition to using `KILOCODE_API_KEY` to align with the new tool's branding, while ensuring the underlying Gemini API access remains secure.

### Steps:
1.  **Environment Variable Setup**:
    -   The provided Google Cloud API key will be configured as `KILOCODE_API_KEY`.
    -   A setup script `scripts/setup-kilocode.sh` will be created to help developers and CI/CD pipelines configure this key securely.
    -   The script will validate the key by making a test call to the API.

2.  **Secret Management**:
    -   Instructions will be provided to update GitHub Secrets or local `.env` files to use `KILOCODE_API_KEY`.

## 3. Workflow Translation

Existing workflows that rely on `gemini-cli` will be updated to use `kilocode-cli`.

### Affected Files:
1.  **`scripts/analyze-version-bump.sh`**:
    -   Current: Calls `gemini-cli` to analyze commits.
    -   New: Will call `kilocode-cli` (or `scripts/kilocode-cli.cjs`).
    -   Update error handling and fallback logic to match the new CLI's output.

2.  **`scripts/analyze-platforms.sh`**:
    -   Current: Checks for `gemini-cli` in PATH or uses local script.
    -   New: Will check for `kilocode-cli` and use `scripts/kilocode-cli.cjs`.

3.  **Documentation**:
    -   Update `docs/AI-VERSIONING.md` and `docs/SETUP-GEMINI.md` (renaming to `docs/SETUP-KILOCODE.md`) to reflect the new tool names and configuration steps.

## 4. Verification Strategy

To ensure the migration is successful and functionality is preserved:

1.  **Unit Testing**:
    -   Run `scripts/kilocode-cli.cjs` directly with a test prompt to verify it can communicate with the Gemini API and return valid JSON.
    -   Command: `./scripts/kilocode-cli.cjs "Test prompt"`

2.  **Integration Testing**:
    -   Run `scripts/analyze-version-bump.sh` in a dry-run mode (or check its output) to ensure it correctly parses the output from `kilocode-cli`.
    -   Verify that version bump logic (Major/Minor/Patch) remains consistent.

3.  **Access Level Verification**:
    -   Confirm that the new `KILOCODE_API_KEY` provides the same access rights as the previous setup by successfully performing a complex analysis task (e.g., analyzing a set of commits).

## Rollback Plan
In case of critical failure, the `gemini-cli.cjs` script will be retained temporarily. Reverting involves:
1.  Restoring the calls in shell scripts to point back to `gemini-cli`.
2.  Ensuring `GEMINI_API_KEY` is still available in the environment.