#!/bin/bash
# Setup GitHub Actions Runner to start automatically on WSL boot

set -e

RUNNER_DIR="$HOME/actions-runner"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.bash_profile"

echo "Setting up auto-start for GitHub Actions Runner..."
echo ""

# Check if runner exists
if [ ! -d "$RUNNER_DIR" ]; then
    echo "ERROR: Runner directory not found at $RUNNER_DIR"
    exit 1
fi

if [ ! -f "$RUNNER_DIR/config.sh" ]; then
    echo "ERROR: Runner not configured. Run setup-wsl-linux-runner.sh first"
    exit 1
fi

# Create startup script
echo "Creating runner startup script..."
cat > "$RUNNER_DIR/start-runner.sh" << 'EOF'
#!/bin/bash
# Start GitHub Actions Runner if not already running

RUNNER_DIR="$HOME/actions-runner"
PID_FILE="$RUNNER_DIR/runner.pid"

# Check if runner is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Runner already running (PID: $PID)"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Start runner in background
cd "$RUNNER_DIR"
nohup ./run.sh > runner.log 2>&1 &
RUNNER_PID=$!

# Save PID
echo $RUNNER_PID > "$PID_FILE"

echo "Runner started (PID: $RUNNER_PID)"
EOF

chmod +x "$RUNNER_DIR/start-runner.sh"

# Add to bashrc
echo "Adding to ~/.bashrc for auto-start..."
AUTOSTART_CMD="if [ -f \"\$HOME/actions-runner/start-runner.sh\" ]; then \$HOME/actions-runner/start-runner.sh & fi"

if [ -f "$BASHRC" ]; then
    # Check if already added
    if ! grep -q "actions-runner/start-runner.sh" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# Auto-start GitHub Actions Runner" >> "$BASHRC"
        echo "$AUTOSTART_CMD" >> "$BASHRC"
        echo "Added to ~/.bashrc"
    else
        echo "Already configured in ~/.bashrc"
    fi
else
    echo "$AUTOSTART_CMD" > "$BASHRC"
    echo "Created ~/.bashrc with auto-start"
fi

# Also add to bash_profile if it exists
if [ -f "$PROFILE" ]; then
    if ! grep -q "actions-runner/start-runner.sh" "$PROFILE"; then
        echo "" >> "$PROFILE"
        echo "# Auto-start GitHub Actions Runner" >> "$PROFILE"
        echo "$AUTOSTART_CMD" >> "$PROFILE"
        echo "Added to ~/.bash_profile"
    fi
fi

echo ""
echo "========================================"
echo "Auto-start configured!"
echo "========================================"
echo ""
echo "The runner will now start automatically when:"
echo "  1. You open a new WSL terminal"
echo "  2. WSL starts (if configured)"
echo ""
echo "To start immediately:"
echo "  ~/actions-runner/start-runner.sh"
echo ""
echo "To stop the runner:"
echo "  pkill -f Runner.Listener"
echo ""
echo "To check if running:"
echo "  ps aux | grep Runner.Listener"

