# First-Time Setup Guide

## Overview

Welcome to CloudToLocalLLM! This guide will help you get started with your first-time setup. The setup wizard will guide you through downloading and installing the desktop client, creating your secure connection, and validating that everything works correctly.

## What You'll Need

- A computer running Windows, Linux, or macOS
- Internet connection for downloading the desktop client
- Administrative privileges to install software (on some platforms)
- A local LLM running with Ollama (optional - can be set up later)

## Setup Process Overview

The first-time setup wizard consists of 8 main steps:

1. **Welcome & Overview** - Introduction to CloudToLocalLLM
2. **Container Creation** - Setting up your isolated streaming proxy
3. **Platform Detection** - Automatic detection of your operating system
4. **Download Client** - Downloading the appropriate desktop client
5. **Installation Guide** - Step-by-step installation instructions
6. **Tunnel Configuration** - Establishing secure connection
7. **Validation & Testing** - Verifying everything works
8. **Completion** - Final setup confirmation

## Step-by-Step Instructions

### Step 1: Welcome & Overview

When you first log into CloudToLocalLLM, you'll see a welcome screen that explains:
- What CloudToLocalLLM does
- Why you need the desktop client
- What the setup process involves

Click **"Get Started"** to begin the setup process.

### Step 2: Container Creation

The system will automatically create your personal streaming proxy container. This provides:
- Isolated environment for your connections
- Enhanced security and privacy
- Dedicated resources for your LLM interactions

You'll see a progress indicator while this happens. This usually takes 30-60 seconds.

### Step 3: Platform Detection

The wizard will automatically detect your operating system and recommend the best download option:

- **Windows**: MSI installer (recommended) or portable ZIP
- **Linux**: AppImage (universal) or DEB package
- **macOS**: DMG application bundle

If detection fails, you can manually select your platform.

### Step 4: Download Client

Choose your preferred download option and click the download button. The wizard will:
- Provide direct download links
- Show file sizes and descriptions
- Track download progress (where possible)

**Download Options by Platform:**

#### Windows
- **MSI Installer** (Recommended): Easy installation with Start Menu integration
- **Portable ZIP**: No installation required, run from any folder

#### Linux
- **AppImage** (Recommended): Universal format, works on all distributions
- **DEB Package**: For Debian/Ubuntu systems with package manager integration

#### macOS
- **DMG Bundle**: Standard macOS application installer

### Step 5: Installation Guide

After downloading, follow the platform-specific installation instructions:

#### Windows Installation
1. **MSI Installer**: Double-click the downloaded .msi file and follow the installer
2. **Portable ZIP**: Extract to your preferred location and run the executable

#### Linux Installation
1. **AppImage**: Make executable and run directly
   ```bash
   chmod +x CloudToLocalLLM-*.AppImage
   ./CloudToLocalLLM-*.AppImage
   ```
2. **DEB Package**: Install using package manager
   ```bash
   sudo dpkg -i cloudtolocalllm_*.deb
   sudo apt-get install -f  # Fix dependencies if needed
   ```

#### macOS Installation
1. Open the downloaded DMG file
2. Drag CloudToLocalLLM to your Applications folder
3. Launch from Applications (you may need to allow in Security preferences)

### Step 6: Tunnel Configuration

Once the desktop client is installed:

1. Launch the CloudToLocalLLM desktop application
2. The wizard will provide connection details specific to your account
3. Enter these details in the desktop client
4. The client will establish a secure tunnel to the web application

**Connection Details Include:**
- Tunnel URL
- Authentication token
- Connection timeout settings

### Step 7: Validation & Testing

The wizard will run comprehensive tests to ensure everything is working:

1. **Desktop Client Communication**: Verifies the web app can reach your desktop client
2. **Tunnel Connectivity**: Tests the secure tunnel connection
3. **Local LLM Access**: Attempts to connect to your local LLM (if available)
4. **Streaming Functionality**: Tests real-time response streaming

Each test will show a progress indicator and success/failure status.

### Step 8: Completion

Once all tests pass, you'll see a success message confirming:
- Your setup is complete
- Your desktop client is connected
- You're ready to start using CloudToLocalLLM

Click **"Start Using CloudToLocalLLM"** to access the main application.

## Troubleshooting Common Issues

### Download Issues

**Problem**: Download fails or is corrupted
**Solutions**:
- Try a different browser
- Disable browser extensions temporarily
- Check your internet connection
- Use the alternative download mirrors provided

**Problem**: Antivirus blocks the download
**Solutions**:
- Temporarily disable antivirus during download
- Add CloudToLocalLLM to antivirus whitelist
- Download from the official GitHub releases page

### Installation Issues

**Problem**: Windows installer fails
**Solutions**:
- Run installer as Administrator
- Temporarily disable antivirus
- Try the portable ZIP version instead
- Check Windows Event Viewer for specific errors

**Problem**: Linux AppImage won't run
**Solutions**:
- Ensure file is executable: `chmod +x CloudToLocalLLM-*.AppImage`
- Install FUSE if missing: `sudo apt install fuse`
- Try running from terminal to see error messages

**Problem**: macOS blocks the application
**Solutions**:
- Go to System Preferences > Security & Privacy
- Click "Allow" for CloudToLocalLLM
- Or run: `sudo xattr -rd com.apple.quarantine /Applications/CloudToLocalLLM.app`

### Connection Issues

**Problem**: Desktop client can't connect to web app
**Solutions**:
- Check firewall settings (allow CloudToLocalLLM)
- Verify internet connection
- Try restarting the desktop client
- Check if corporate network blocks WebSocket connections

**Problem**: Tunnel connection fails
**Solutions**:
- Verify connection details are entered correctly
- Check for proxy/VPN interference
- Try different network (mobile hotspot)
- Contact support if corporate firewall blocks connections

**Problem**: Local LLM not detected
**Solutions**:
- Ensure Ollama is running: `ollama serve`
- Check Ollama is accessible: `ollama list`
- Verify Ollama is running on default port (11434)
- Try restarting Ollama service

### Validation Test Failures

**Problem**: Desktop client communication test fails
**Solutions**:
- Restart the desktop client
- Check Windows Defender/antivirus isn't blocking
- Verify the client is running and visible in system tray
- Try running client as Administrator (Windows)

**Problem**: Streaming test fails
**Solutions**:
- Ensure local LLM is running and responsive
- Check Ollama has models installed: `ollama list`
- Try a simple Ollama query: `ollama run llama2 "Hello"`
- Restart both desktop client and Ollama

## Getting Help

If you continue to experience issues:

1. **Check the FAQ** below for common solutions
2. **Review the troubleshooting guides** in the help section
3. **Contact Support** through the help menu
4. **Visit our Documentation** at [docs link]
5. **Join our Community** for peer support

## Frequently Asked Questions

### General Questions

**Q: Do I need to install anything locally?**
A: Yes, you need the CloudToLocalLLM desktop client to create a secure tunnel between the web app and your local LLM.

**Q: Is my data sent to the cloud?**
A: No, all your conversations and data remain on your local machine. The web app only facilitates the connection.

**Q: Can I use CloudToLocalLLM without a local LLM?**
A: The desktop client is required for the secure tunnel, but you can set up your local LLM later.

**Q: Which LLMs are supported?**
A: CloudToLocalLLM works with any Ollama-compatible LLM. Popular options include Llama 2, Code Llama, Mistral, and many others.

### Technical Questions

**Q: What ports does CloudToLocalLLM use?**
A: The desktop client uses dynamic ports for the tunnel connection. No manual port configuration is required.

**Q: Can I run multiple instances?**
A: Each user account can have one active desktop client connection at a time.

**Q: How do I update the desktop client?**
A: The client will notify you of updates. Download the new version and install over the existing one.

**Q: Can I use CloudToLocalLLM on multiple devices?**
A: Yes, but each device needs its own desktop client installation and setup.

### Troubleshooting Questions

**Q: The setup wizard doesn't appear**
A: This usually means you've already completed setup. Check your account settings to re-run the wizard if needed.

**Q: My platform wasn't detected correctly**
A: Use the manual platform selection option in the wizard to choose the correct platform.

**Q: The download is very slow**
A: Try using a different browser or network connection. Alternative download mirrors are provided if the primary fails.

**Q: I can't find the downloaded file**
A: Check your browser's default download folder, usually `Downloads` in your user directory.

## Advanced Configuration

### Manual Configuration

If the automatic setup fails, you can manually configure the connection:

1. Launch the desktop client
2. Go to Settings > Connection
3. Enter the following details from your web app account:
   - Server URL: `wss://cloudtolocalllm.online/ws`
   - Auth Token: [from your account settings]
   - User ID: [your account ID]

### Network Configuration

For corporate networks or complex setups:

1. **Proxy Settings**: Configure in desktop client settings
2. **Firewall Rules**: Allow CloudToLocalLLM through Windows Firewall
3. **Port Forwarding**: Not required for standard setup
4. **VPN Compatibility**: Should work with most VPN configurations

### Performance Optimization

To optimize performance:

1. **Close unnecessary applications** during setup
2. **Use wired internet connection** if possible
3. **Ensure adequate system resources** (4GB+ RAM recommended)
4. **Keep Ollama updated** to the latest version

## Next Steps

After completing the setup:

1. **Explore the Interface**: Familiarize yourself with the chat interface
2. **Install Local Models**: Use Ollama to install your preferred LLMs
3. **Customize Settings**: Adjust preferences in both web and desktop apps
4. **Join the Community**: Connect with other users for tips and support

Welcome to CloudToLocalLLM! Enjoy secure, private access to your local LLMs.