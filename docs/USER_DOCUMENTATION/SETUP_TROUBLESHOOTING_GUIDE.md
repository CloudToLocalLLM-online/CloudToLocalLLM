# Setup Wizard Troubleshooting Guide

## Overview

This guide helps you resolve common issues encountered during the CloudToLocalLLM first-time setup process. Issues are organized by setup step and include detailed solutions.

## Quick Diagnosis

### Setup Not Starting
**Symptoms**: Setup wizard doesn't appear after login
**Possible Causes**:
- Already completed setup
- Feature not enabled for your account
- Browser compatibility issues

**Solutions**:
1. Check if you've already completed setup (look for setup status in account settings)
2. Try a different browser (Chrome, Firefox, Safari, Edge)
3. Clear browser cache and cookies
4. Contact support if issue persists

### Setup Freezing or Hanging
**Symptoms**: Setup wizard stops responding or gets stuck on a step
**Possible Causes**:
- Network connectivity issues
- Server overload
- Browser memory issues

**Solutions**:
1. Refresh the page and try again
2. Check your internet connection
3. Close other browser tabs to free memory
4. Try using an incognito/private browsing window

## Step-by-Step Troubleshooting

### Step 1: Welcome & Overview
**Common Issues**: None typically occur at this step
**If stuck**: Refresh the page and try again

### Step 2: Container Creation

#### Container Creation Failed
**Error Message**: "Failed to create user container"
**Causes**:
- Server capacity issues
- Network timeout
- Service temporarily unavailable

**Solutions**:
1. **Wait and retry**: Click "Retry" button after 30 seconds
2. **Check server status**: Visit status page for service health
3. **Try later**: If servers are overloaded, try again in a few minutes
4. **Contact support**: If problem persists after multiple retries

#### Container Creation Timeout
**Error Message**: "Container creation timed out"
**Causes**:
- Slow network connection
- Server processing delays
- High server load

**Solutions**:
1. **Increase timeout**: Wait up to 2 minutes before considering it failed
2. **Check connection**: Ensure stable internet connection
3. **Retry setup**: Start the setup process again
4. **Use different network**: Try from a different location/network

### Step 3: Platform Detection

#### Wrong Platform Detected
**Symptoms**: Wizard shows wrong operating system
**Causes**:
- Browser user agent spoofing
- Running in compatibility mode
- Using unusual browser/OS combination

**Solutions**:
1. **Manual selection**: Click "Choose different platform" and select manually
2. **Update browser**: Ensure you're using the latest browser version
3. **Disable extensions**: Temporarily disable browser extensions that might modify user agent
4. **Use standard browser**: Try with Chrome, Firefox, or Edge

#### No Platform Detected
**Error Message**: "Unable to detect your platform"
**Causes**:
- JavaScript disabled
- Very old browser
- Unusual operating system

**Solutions**:
1. **Enable JavaScript**: Ensure JavaScript is enabled in your browser
2. **Manual selection**: Choose your platform from the available options
3. **Update browser**: Use a modern, supported browser
4. **Check compatibility**: Verify your OS is supported (Windows 10+, Ubuntu 18.04+, macOS 10.14+)

### Step 4: Download Client

#### Download Fails to Start
**Symptoms**: Clicking download button does nothing
**Causes**:
- Pop-up blocker enabled
- Download restrictions
- Browser security settings

**Solutions**:
1. **Disable pop-up blocker**: Allow pop-ups for CloudToLocalLLM
2. **Right-click and save**: Right-click download link and "Save link as"
3. **Try different browser**: Use a different browser for download
4. **Check security settings**: Ensure downloads are allowed

#### Download Interrupted or Corrupted
**Symptoms**: Download stops partway or file won't install
**Causes**:
- Network interruption
- Antivirus interference
- Insufficient disk space

**Solutions**:
1. **Check disk space**: Ensure you have enough free space (500MB+)
2. **Disable antivirus temporarily**: Turn off real-time scanning during download
3. **Use download manager**: Use a download manager for large files
4. **Try alternative download**: Use a different download option or mirror

#### Download Speed Very Slow
**Symptoms**: Download takes much longer than expected
**Causes**:
- Network congestion
- Server load
- Geographic distance from servers

**Solutions**:
1. **Wait patiently**: Large files may take time on slower connections
2. **Try different time**: Download during off-peak hours
3. **Use different network**: Try from a different location
4. **Contact ISP**: Check if your internet provider has issues

### Step 5: Installation Guide

#### Installation Permission Denied
**Error Message**: "Permission denied" or "Administrator required"
**Causes**:
- Insufficient user privileges
- UAC (User Account Control) blocking
- Antivirus interference

**Solutions**:

**Windows**:
1. **Run as administrator**: Right-click installer and "Run as administrator"
2. **Disable UAC temporarily**: Lower UAC settings during installation
3. **Add to antivirus whitelist**: Exclude CloudToLocalLLM from antivirus scans

**Linux**:
1. **Use sudo**: Run installation commands with `sudo`
2. **Check file permissions**: Ensure installer file is executable (`chmod +x`)
3. **Install dependencies**: Install required system packages

**macOS**:
1. **Allow in Security & Privacy**: Go to System Preferences > Security & Privacy
2. **Override Gatekeeper**: Control-click and select "Open" for unsigned apps
3. **Check quarantine**: Run `xattr -d com.apple.quarantine filename.app`

#### Missing Dependencies
**Error Message**: Various dependency-related errors
**Causes**:
- Required system libraries not installed
- Outdated system components
- Incomplete system updates

**Solutions**:

**Windows**:
1. **Install Visual C++ Redistributables**: Download from Microsoft
2. **Update Windows**: Install all available Windows updates
3. **Install .NET Framework**: Ensure latest .NET Framework is installed

**Linux**:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install libgtk-3-0 libblkid1 liblzma5

# CentOS/RHEL/Fedora
sudo yum install gtk3 util-linux-ng xz-libs
```

**macOS**:
1. **Update macOS**: Install latest macOS updates
2. **Install Xcode Command Line Tools**: `xcode-select --install`

#### Antivirus False Positive
**Symptoms**: Antivirus blocks or deletes installer
**Causes**:
- New/unsigned executable
- Heuristic detection
- Overly aggressive antivirus settings

**Solutions**:
1. **Add to whitelist**: Add CloudToLocalLLM to antivirus exceptions
2. **Temporarily disable**: Turn off real-time protection during installation
3. **Report false positive**: Submit file to antivirus vendor for analysis
4. **Use different antivirus**: Try with Windows Defender only

### Step 6: Tunnel Configuration

#### Connection Refused
**Error Message**: "Connection refused" or "Unable to connect"
**Causes**:
- Desktop client not running
- Firewall blocking connection
- Incorrect connection details

**Solutions**:
1. **Start desktop client**: Ensure CloudToLocalLLM desktop app is running
2. **Check firewall**: Allow CloudToLocalLLM through Windows/macOS firewall
3. **Verify connection details**: Double-check all connection parameters
4. **Try different port**: If default port is blocked, try alternative ports

#### Firewall Blocking Connection
**Symptoms**: Connection times out or is refused
**Causes**:
- Windows Firewall blocking
- Third-party firewall interference
- Corporate network restrictions

**Solutions**:

**Windows Firewall**:
1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Add CloudToLocalLLM to allowed apps
4. Ensure both Private and Public networks are checked

**Third-party Firewalls**:
1. Add CloudToLocalLLM to firewall exceptions
2. Allow incoming connections on required ports
3. Temporarily disable firewall to test

**Corporate Networks**:
1. Contact IT department for assistance
2. Request ports to be opened
3. Use alternative connection methods if available

#### SSL/TLS Certificate Issues
**Error Message**: "Certificate error" or "SSL handshake failed"
**Causes**:
- System clock incorrect
- Outdated certificate store
- Corporate proxy interference

**Solutions**:
1. **Check system time**: Ensure date and time are correct
2. **Update certificates**: Update system certificate store
3. **Bypass proxy**: Try connecting without corporate proxy
4. **Accept certificate**: Manually accept the certificate if prompted

### Step 7: Validation & Testing

#### Desktop Client Not Responding
**Symptoms**: Validation fails with "Desktop client not responding"
**Causes**:
- Desktop client crashed
- Connection not established
- Client running but not configured

**Solutions**:
1. **Restart desktop client**: Close and reopen the desktop application
2. **Check client logs**: Look for error messages in client logs
3. **Reconfigure connection**: Re-enter connection details in desktop client
4. **Update client**: Ensure you have the latest version

#### Local LLM Not Accessible
**Error Message**: "Cannot connect to local LLM"
**Causes**:
- Ollama not running
- LLM not loaded
- Port conflicts

**Solutions**:
1. **Start Ollama**: Ensure Ollama service is running
2. **Load a model**: Run `ollama pull llama2` or similar
3. **Check Ollama status**: Run `ollama list` to see available models
4. **Verify port**: Ensure Ollama is running on default port (11434)

#### Streaming Test Fails
**Symptoms**: Basic connection works but streaming fails
**Causes**:
- WebSocket connection issues
- Proxy interference
- Network instability

**Solutions**:
1. **Check WebSocket support**: Ensure your network supports WebSockets
2. **Disable proxy**: Temporarily disable HTTP proxy
3. **Test with simple query**: Try a very short test message
4. **Check network stability**: Ensure stable internet connection

## Network and Connectivity Issues

### Corporate Network Problems
**Common Issues**:
- Proxy servers blocking connections
- Firewall restrictions
- Port blocking
- SSL inspection interference

**Solutions**:
1. **Contact IT department**: Request assistance with CloudToLocalLLM setup
2. **Use mobile hotspot**: Temporarily use phone's internet for setup
3. **VPN workaround**: Try using a VPN to bypass restrictions
4. **Alternative ports**: Configure to use different ports if available

### Home Network Issues
**Common Issues**:
- Router firewall blocking
- ISP restrictions
- WiFi instability
- Bandwidth limitations

**Solutions**:
1. **Router configuration**: Check router firewall settings
2. **Use ethernet**: Connect directly via ethernet cable
3. **Contact ISP**: Check if ISP blocks certain connections
4. **Quality of Service**: Prioritize CloudToLocalLLM traffic in router settings

## Platform-Specific Issues

### Windows-Specific Problems

#### Windows Defender SmartScreen
**Symptoms**: "Windows protected your PC" message
**Solutions**:
1. Click "More info" then "Run anyway"
2. Add to SmartScreen exceptions
3. Temporarily disable SmartScreen

#### Windows Update Issues
**Symptoms**: Installation fails due to missing updates
**Solutions**:
1. Run Windows Update
2. Install all available updates
3. Restart and try again

### Linux-Specific Problems

#### AppImage Won't Run
**Symptoms**: AppImage file won't execute
**Solutions**:
```bash
# Make executable
chmod +x CloudToLocalLLM.AppImage

# Install FUSE if needed
sudo apt install fuse

# Run with --appimage-extract-and-run if FUSE unavailable
./CloudToLocalLLM.AppImage --appimage-extract-and-run
```

#### DEB Package Issues
**Symptoms**: Package installation fails
**Solutions**:
```bash
# Fix broken dependencies
sudo apt --fix-broken install

# Force install if needed
sudo dpkg -i --force-depends cloudtolocalllm.deb

# Install missing dependencies
sudo apt install -f
```

### macOS-Specific Problems

#### Gatekeeper Blocking
**Symptoms**: "App can't be opened because it is from an unidentified developer"
**Solutions**:
1. Control-click app and select "Open"
2. Go to System Preferences > Security & Privacy > General
3. Click "Open Anyway" next to the blocked app message

#### Quarantine Issues
**Symptoms**: App won't run even after allowing in Security & Privacy
**Solutions**:
```bash
# Remove quarantine attribute
sudo xattr -rd com.apple.quarantine /Applications/CloudToLocalLLM.app

# Or for downloaded file
xattr -d com.apple.quarantine CloudToLocalLLM.dmg
```

## Advanced Troubleshooting

### Log Collection
If you need to contact support, collect these logs:

**Browser Console Logs**:
1. Open browser developer tools (F12)
2. Go to Console tab
3. Reproduce the issue
4. Copy all error messages

**Desktop Client Logs**:
- **Windows**: `%APPDATA%\CloudToLocalLLM\logs\`
- **Linux**: `~/.config/CloudToLocalLLM/logs/`
- **macOS**: `~/Library/Application Support/CloudToLocalLLM/logs/`

### Network Diagnostics
```bash
# Test basic connectivity
ping cloudtolocalllm.online

# Test HTTPS connectivity
curl -I https://cloudtolocalllm.online

# Test WebSocket connectivity (if available)
wscat -c wss://cloudtolocalllm.online/ws
```

### System Information Collection
When contacting support, provide:
- Operating system and version
- Browser type and version
- Desktop client version
- Error messages (exact text)
- Steps to reproduce the issue

## Getting Additional Help

### Self-Service Resources
1. **FAQ Section**: Check frequently asked questions
2. **User Guide**: Review the complete setup guide
3. **Video Tutorials**: Watch setup walkthrough videos
4. **Community Forums**: Search existing discussions

### Contact Support
If self-service doesn't resolve your issue:

1. **Gather information**: Collect logs and system details
2. **Document steps**: Write down exactly what you did
3. **Include screenshots**: Visual evidence helps diagnosis
4. **Be specific**: Describe the exact error messages

### Emergency Workarounds
If setup completely fails:

1. **Manual installation**: Download and install desktop client manually
2. **Direct configuration**: Configure connection manually using provided details
3. **Alternative setup**: Use a different device or network for initial setup
4. **Temporary solution**: Use web-only mode if available (limited functionality)

## Prevention Tips

### Before Starting Setup
1. **Check system requirements**: Ensure your system meets minimum requirements
2. **Update everything**: Update OS, browser, and security software
3. **Free up space**: Ensure adequate disk space (1GB+ recommended)
4. **Stable connection**: Use reliable internet connection
5. **Disable interference**: Temporarily disable VPN, proxy, aggressive antivirus

### During Setup
1. **Don't multitask**: Focus on setup, avoid other intensive tasks
2. **Stay connected**: Don't let computer sleep or disconnect
3. **Be patient**: Some steps take time, especially container creation
4. **Read carefully**: Follow instructions exactly as written

### After Setup
1. **Test thoroughly**: Verify all functionality works
2. **Bookmark important pages**: Save links to documentation and support
3. **Note configuration**: Record your setup details for future reference
4. **Update regularly**: Keep desktop client updated

This troubleshooting guide should resolve most common setup issues. If you encounter a problem not covered here, please contact support with detailed information about your specific situation.