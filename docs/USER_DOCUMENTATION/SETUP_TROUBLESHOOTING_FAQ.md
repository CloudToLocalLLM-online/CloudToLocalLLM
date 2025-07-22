# Setup Troubleshooting Guide & FAQ

## Quick Troubleshooting Checklist

Before diving into specific issues, try these common solutions:

1. **Refresh the page** and try again
2. **Clear browser cache** and cookies
3. **Disable browser extensions** temporarily
4. **Check internet connection** stability
5. **Try a different browser** (Chrome, Firefox, Safari, Edge)
6. **Restart the desktop client** if already installed
7. **Check firewall/antivirus** isn't blocking CloudToLocalLLM

## Common Setup Issues

### Setup Wizard Doesn't Appear

**Symptoms:**
- Login successful but no setup wizard shows
- Redirected directly to main application
- "Get Started" button missing

**Possible Causes:**
- Setup already completed previously
- Browser cache showing old version
- Account configuration issue

**Solutions:**
1. **Check Setup Status:**
   - Go to Settings > Account
   - Look for "Setup Status" or "Re-run Setup"
   - Click "Reset Setup" if available

2. **Clear Browser Data:**
   ```
   Chrome: Settings > Privacy > Clear browsing data
   Firefox: Settings > Privacy > Clear Data
   Safari: Develop > Empty Caches
   Edge: Settings > Privacy > Clear browsing data
   ```

3. **Force Setup Reset:**
   - Contact support to reset your setup status
   - Provide your account email for verification

### Container Creation Fails

**Symptoms:**
- "Creating your container..." step hangs
- Error message about container creation
- Step 2 never completes

**Possible Causes:**
- Server overload or maintenance
- Network connectivity issues
- Account permissions problem

**Solutions:**
1. **Wait and Retry:**
   - Container creation can take 1-2 minutes
   - Don't refresh the page during creation
   - Click "Retry" if the option appears

2. **Check Server Status:**
   - Visit [status.cloudtolocalllm.online] for service status
   - Check our Twitter [@CloudToLocalLLM] for updates
   - Try again during off-peak hours

3. **Network Troubleshooting:**
   - Disable VPN temporarily
   - Try different network (mobile hotspot)
   - Check corporate firewall settings

### Platform Detection Issues

**Symptoms:**
- Wrong operating system detected
- "Unknown platform" message
- Missing download options

**Possible Causes:**
- Unusual browser user agent
- Unsupported operating system
- Browser compatibility issue

**Solutions:**
1. **Manual Platform Selection:**
   - Look for "Manual Selection" or "Choose Platform"
   - Select your correct operating system
   - Proceed with appropriate download

2. **Browser Compatibility:**
   - Try Chrome or Firefox (best supported)
   - Update browser to latest version
   - Disable browser extensions

3. **Supported Platforms:**
   - Windows 10/11 (64-bit)
   - Linux (Ubuntu 18.04+, most distributions)
   - macOS 10.14+ (Mojave and newer)

### Download Problems

**Symptoms:**
- Download doesn't start
- Download fails or corrupts
- "File not found" errors
- Very slow download speeds

**Possible Causes:**
- Network connectivity issues
- Browser download restrictions
- Antivirus blocking download
- Server overload

**Solutions:**
1. **Alternative Download Methods:**
   - Try different browser
   - Use incognito/private mode
   - Right-click download link > "Save as"
   - Try alternative download mirrors

2. **Network Issues:**
   - Check internet connection stability
   - Disable VPN/proxy temporarily
   - Try different network
   - Pause other downloads/streaming

3. **Antivirus/Security:**
   - Temporarily disable antivirus
   - Add CloudToLocalLLM to whitelist
   - Check Windows Defender exclusions
   - Disable browser security extensions

4. **Alternative Sources:**
   - Visit GitHub releases directly
   - Use official download page
   - Contact support for direct links

### Installation Failures

#### Windows Installation Issues

**MSI Installer Problems:**
- "Installation package corrupt" error
- "Insufficient privileges" message
- Installation hangs or freezes

**Solutions:**
1. **Run as Administrator:**
   - Right-click MSI file
   - Select "Run as administrator"
   - Accept UAC prompt

2. **Windows Installer Issues:**
   - Download and install latest Windows Installer
   - Run Windows Update
   - Restart computer and try again

3. **Antivirus Interference:**
   - Temporarily disable real-time protection
   - Add installer to exclusions
   - Try installation in Safe Mode

**Portable ZIP Issues:**
- "File is corrupted" error
- Missing files after extraction
- Application won't start

**Solutions:**
1. **Re-download and Extract:**
   - Download ZIP file again
   - Use different extraction tool (7-Zip, WinRAR)
   - Extract to different location

2. **Permissions:**
   - Extract to user folder (not Program Files)
   - Right-click folder > Properties > Security
   - Ensure full control permissions

#### Linux Installation Issues

**AppImage Problems:**
- "Permission denied" error
- AppImage won't execute
- Missing dependencies

**Solutions:**
1. **Make Executable:**
   ```bash
   chmod +x CloudToLocalLLM-*.AppImage
   ./CloudToLocalLLM-*.AppImage
   ```

2. **Install FUSE:**
   ```bash
   # Ubuntu/Debian
   sudo apt install fuse libfuse2
   
   # CentOS/RHEL
   sudo yum install fuse fuse-libs
   
   # Arch Linux
   sudo pacman -S fuse2
   ```

3. **Extract and Run:**
   ```bash
   ./CloudToLocalLLM-*.AppImage --appimage-extract
   ./squashfs-root/AppRun
   ```

**DEB Package Problems:**
- Dependency conflicts
- Package installation fails
- "Package is of bad quality" warning

**Solutions:**
1. **Fix Dependencies:**
   ```bash
   sudo apt update
   sudo apt install -f
   sudo dpkg -i cloudtolocalllm_*.deb
   sudo apt install -f
   ```

2. **Force Installation:**
   ```bash
   sudo dpkg -i --force-depends cloudtolocalllm_*.deb
   sudo apt install -f
   ```

#### macOS Installation Issues

**DMG/App Bundle Problems:**
- "App is damaged" message
- "Unidentified developer" warning
- App won't open

**Solutions:**
1. **Security Settings:**
   - System Preferences > Security & Privacy
   - Click "Open Anyway" for CloudToLocalLLM
   - Or allow apps from "App Store and identified developers"

2. **Remove Quarantine:**
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/CloudToLocalLLM.app
   ```

3. **Gatekeeper Issues:**
   ```bash
   sudo spctl --master-disable
   # Install app, then re-enable:
   sudo spctl --master-enable
   ```

### Connection and Tunnel Issues

**Symptoms:**
- Desktop client can't connect to web app
- "Tunnel connection failed" error
- Connection drops frequently
- Slow response times

**Possible Causes:**
- Firewall blocking connections
- Network proxy interference
- Desktop client not running
- Incorrect configuration

**Solutions:**
1. **Firewall Configuration:**
   - Windows: Allow CloudToLocalLLM through Windows Firewall
   - Linux: Configure iptables/ufw rules
   - macOS: System Preferences > Security > Firewall
   - Router: Check port forwarding/UPnP settings

2. **Desktop Client Issues:**
   - Ensure client is running (check system tray)
   - Restart desktop client
   - Run client as administrator (Windows)
   - Check client logs for errors

3. **Network Troubleshooting:**
   - Disable VPN/proxy temporarily
   - Try different network
   - Check corporate firewall settings
   - Test with mobile hotspot

4. **Manual Configuration:**
   - Get connection details from web app settings
   - Manually enter in desktop client
   - Verify server URL and authentication token
   - Check timeout settings

### Validation Test Failures

**Desktop Client Communication Test:**
- Ensure desktop client is running
- Check system tray for CloudToLocalLLM icon
- Restart client if not responding
- Verify client version compatibility

**Tunnel Connectivity Test:**
- Check network connection stability
- Disable VPN/proxy temporarily
- Verify firewall isn't blocking WebSocket connections
- Try different network

**Local LLM Connection Test:**
- Ensure Ollama is installed and running
- Check Ollama service status: `ollama serve`
- Verify models are installed: `ollama list`
- Test Ollama directly: `ollama run llama2 "Hello"`

**Streaming Functionality Test:**
- Ensure local LLM is responsive
- Check Ollama performance and resources
- Verify streaming isn't blocked by network
- Test with simpler model if available

## Platform-Specific Troubleshooting

### Windows Specific Issues

**Windows Defender SmartScreen:**
- Click "More info" then "Run anyway"
- Or add to Windows Defender exclusions

**PowerShell Execution Policy:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Windows Firewall:**
- Control Panel > System and Security > Windows Defender Firewall
- Click "Allow an app or feature through Windows Defender Firewall"
- Add CloudToLocalLLM to exceptions

**Registry Issues:**
- Run `sfc /scannow` as administrator
- Run `DISM /Online /Cleanup-Image /RestoreHealth`

### Linux Specific Issues

**Missing Dependencies:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install libgtk-3-0 libblkid1 liblzma5

# CentOS/RHEL
sudo yum install gtk3 util-linux-ng xz

# Arch Linux
sudo pacman -S gtk3 util-linux xz
```

**Permission Issues:**
```bash
# Add user to necessary groups
sudo usermod -a -G docker $USER
sudo usermod -a -G audio $USER

# Fix file permissions
chmod +x CloudToLocalLLM-*.AppImage
```

**Display Issues:**
```bash
# For Wayland users
export GDK_BACKEND=x11

# For HiDPI displays
export GDK_SCALE=2
```

### macOS Specific Issues

**Rosetta 2 (Apple Silicon):**
```bash
sudo softwareupdate --install-rosetta
```

**Homebrew Dependencies:**
```bash
brew install --cask xquartz
brew install gtk+3
```

**Path Issues:**
```bash
export PATH="/usr/local/bin:$PATH"
```

## Network and Corporate Environment Issues

### Corporate Firewall

**Common Blocked Ports:**
- WebSocket connections (port 443/80)
- Custom application ports
- Outbound HTTPS to GitHub

**Solutions:**
1. Contact IT department for whitelist
2. Use mobile hotspot for initial setup
3. Request proxy configuration details
4. Try alternative download sources

### Proxy Configuration

**Desktop Client Proxy Settings:**
1. Open desktop client settings
2. Go to Network > Proxy
3. Enter corporate proxy details
4. Test connection

**Browser Proxy Issues:**
- Disable proxy for CloudToLocalLLM domains
- Add to proxy bypass list
- Use direct connection temporarily

### VPN Interference

**Common Issues:**
- Split tunneling conflicts
- DNS resolution problems
- Port blocking

**Solutions:**
1. Disable VPN during setup
2. Configure split tunneling
3. Use VPN's DNS servers
4. Contact VPN provider for support

## Advanced Troubleshooting

### Log Collection

**Browser Console Logs:**
1. Press F12 to open developer tools
2. Go to Console tab
3. Reproduce the issue
4. Copy all error messages

**Desktop Client Logs:**
- Windows: `%APPDATA%\CloudToLocalLLM\logs\`
- Linux: `~/.config/CloudToLocalLLM/logs/`
- macOS: `~/Library/Application Support/CloudToLocalLLM/logs/`

**System Information:**
- Operating system version
- Browser version
- Desktop client version
- Network configuration
- Antivirus software

### Manual Configuration

**Connection Parameters:**
```json
{
  "serverUrl": "wss://cloudtolocalllm.online/ws",
  "authToken": "[from account settings]",
  "userId": "[your user ID]",
  "timeout": 30000
}
```

**Desktop Client Config File:**
- Windows: `%APPDATA%\CloudToLocalLLM\config.json`
- Linux: `~/.config/CloudToLocalLLM/config.json`
- macOS: `~/Library/Application Support/CloudToLocalLLM/config.json`

### Database Reset

If setup state becomes corrupted:
1. Contact support with account email
2. Request setup status reset
3. Clear browser data completely
4. Restart setup process

## Frequently Asked Questions

### General Questions

**Q: How long should the setup process take?**
A: Typically 5-10 minutes, depending on download speed and platform. Container creation takes 1-2 minutes.

**Q: Can I skip steps in the setup wizard?**
A: Some steps can be skipped, but this may result in incomplete functionality. The wizard will warn you about consequences.

**Q: Do I need administrator privileges?**
A: Windows MSI installer requires admin rights. Portable versions and Linux/macOS typically don't.

**Q: Can I run the setup wizard again?**
A: Yes, go to Settings > Account > Reset Setup, or contact support to reset your setup status.

**Q: What if my platform isn't supported?**
A: Currently supports Windows 10+, Linux (most distributions), and macOS 10.14+. Contact support for specific requirements.

### Technical Questions

**Q: What ports does CloudToLocalLLM use?**
A: The desktop client uses dynamic ports. The web app connects via standard HTTPS (443) and WebSocket connections.

**Q: Does CloudToLocalLLM work with corporate proxies?**
A: Yes, configure proxy settings in the desktop client. Contact IT for whitelist requirements.

**Q: Can I use CloudToLocalLLM offline?**
A: The desktop client needs internet connection to establish the tunnel. Local LLM interactions happen locally.

**Q: How much bandwidth does CloudToLocalLLM use?**
A: Minimal bandwidth for control messages. LLM responses stream locally, not through the cloud.

**Q: Is my data sent to CloudToLocalLLM servers?**
A: No, all conversations and data remain on your local machine. Only connection metadata is transmitted.

### Troubleshooting Questions

**Q: The download is very slow, what can I do?**
A: Try a different browser, disable VPN, use alternative download mirrors, or try during off-peak hours.

**Q: My antivirus is blocking the installation, is it safe?**
A: Yes, CloudToLocalLLM is safe. Add to antivirus exclusions or download from official sources only.

**Q: The desktop client won't start after installation**
A: Check system requirements, run as administrator (Windows), verify file permissions (Linux), or check security settings (macOS).

**Q: Connection tests fail but everything seems correct**
A: Check firewall settings, try different network, restart desktop client, or verify local LLM is running.

**Q: Can I install on multiple computers?**
A: Yes, each device needs its own desktop client installation and setup.

## Getting Additional Help

### Support Channels

1. **Documentation**: Check our comprehensive docs at [docs.cloudtolocalllm.online]
2. **Community Forum**: Join discussions at [community.cloudtolocalllm.online]
3. **GitHub Issues**: Report bugs at [github.com/CloudToLocalLLM/issues]
4. **Email Support**: Contact support@cloudtolocalllm.online
5. **Discord**: Join our Discord server for real-time help

### Before Contacting Support

Please gather this information:
- Operating system and version
- Browser type and version
- Desktop client version (if installed)
- Error messages (exact text or screenshots)
- Steps to reproduce the issue
- Network environment (home/corporate/VPN)

### Emergency Workarounds

If setup completely fails:
1. Use the dedicated download page: [cloudtolocalllm.online/downloads]
2. Download desktop client manually from GitHub releases
3. Follow manual configuration guide
4. Contact support for direct assistance

Remember: Most setup issues are temporary and can be resolved with patience and the right troubleshooting steps. Don't hesitate to reach out for help!