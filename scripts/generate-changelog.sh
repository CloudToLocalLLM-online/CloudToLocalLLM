#!/bin/bash
set -e

# Generate CHANGELOG.md using Gemini AI based on git commits
# Usage: ./generate-changelog.sh <new-version>

NEW_VERSION="$1"
if [ -z "$NEW_VERSION" ]; then
    echo "❌ Usage: $0 <new-version>"
    exit 1
fi

# Get the latest tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Generating Changelog for v$NEW_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "$LAST_TAG" ]; then
    echo "No previous tag found. Getting all commits..."
    COMMITS=$(git log --pretty=format:"* %s (%h)" --no-merges)
else
    echo "Getting commits since $LAST_TAG..."
    COMMITS=$(git log --pretty=format:"* %s (%h)" --no-merges ${LAST_TAG}..HEAD)
fi

if [ -z "$COMMITS" ]; then
    echo "No new commits found."
    exit 0
fi

# Prepare prompt for Gemini
PROMPT="Analyze the following git commits and generate a professional CHANGELOG entry for version $NEW_VERSION.
Group changes into categories: Features, Bug Fixes, Security, Performance, Documentation, Refactoring, and Chore.
Use Markdown format. Output ONLY the changelog content.

Commits:
$COMMITS"

# Get response from Gemini
if ! command -v gemini >/dev/null 2>&1; then
    echo "❌ CRITICAL FAILURE: 'gemini' command not found. Ensure the Gemini CLI is installed and in your PATH."
    exit 1
fi

echo "🚀 Requesting changelog from Gemini AI..."
# Use gemini CLI to generate the changelog
CHANGELOG_ENTRY=$(gemini "$PROMPT" --yolo --model gemini-1.5-flash)

if [ -z "$CHANGELOG_ENTRY" ]; then
    echo "❌ CRITICAL FAILURE: Gemini AI returned an empty response. Cannot generate changelog."
    exit 1
fi

echo "✅ Received response from Gemini."

# Clean up the response (remove code blocks if any)
CHANGELOG_ENTRY=$(echo "$CHANGELOG_ENTRY" | sed 's/```markdown//g' | sed 's/```//g')

# Prepend to CHANGELOG.md
DATE=$(date +"%Y-%m-%d")
HEADER="## [$NEW_VERSION] - $DATE"

if [ ! -f "CHANGELOG.md" ]; then
    echo "# Changelog" > CHANGELOG.md
    echo "" >> CHANGELOG.md
    echo "All notable changes to this project will be documented in this file." >> CHANGELOG.md
    echo "" >> CHANGELOG.md
fi

# Create a temporary file
TEMP_FILE=$(mktemp)
echo "# Changelog" > $TEMP_FILE
echo "" >> $TEMP_FILE
echo "All notable changes to this project will be documented in this file." >> $TEMP_FILE
echo "" >> $TEMP_FILE
echo "$HEADER" >> $TEMP_FILE
echo "$CHANGELOG_ENTRY" >> $TEMP_FILE
echo "" >> $TEMP_FILE

# Append the rest of the existing changelog (skipping the first 4 lines)
if [ -f "CHANGELOG.md" ]; then
    tail -n +5 CHANGELOG.md >> $TEMP_FILE
fi

mv $TEMP_FILE CHANGELOG.md

echo "✅ CHANGELOG.md updated successfully"
