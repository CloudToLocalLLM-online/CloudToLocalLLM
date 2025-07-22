# Setup Wizard Troubleshooting Guide

## Quick Troubleshooting Checklist

Before diving into specific issues, try these common solutions:

1. **Refresh the page** and try again
2. **Check your internet connection** is stable
3. **Disable browser extensions** temporarily
4. **Clear browser cache and cookies** for cloudtolocalllm.online
5. **Try a different browser** (Chrome, Firefox, Safari, Edge)
6. **Ensure your local LLM is running** (Ollama or compatible)
7. **Check firewall and antivirus settings**

## Common Issues and Solutions

### Container Creation Issues

#### Problem: "Container creation failed" or "Unable to create secure container"

**Possible Causes:**
- Server overload or maintenance
- Network connectivity issues
- Account permissions problems

**Solutions:**
1. **Wait and retry**: Server may be experiencing high load
   - Wait 2-3 minutes and click "Retry"
   - Try during off-peak hours if problem persists

2. **Check account status**:
   - Ensure your account is active and verified
   - Log out and log back in to refresh your session

3. **Network troubleshooting**:
   - Test your internet connection with other websites
   - Try switching to a different network (mobile hotspot)
   - Disable VPN temporarily if you're using one

4. **Contact support** if the issue persists after multiple attempts

#### Problem: Container creation hangs or takes too long

**Solutions:**
1. **Wait up to 2 minutes** - container creation can take time
2. **Refresh the page** if stuck for more than 3 minutes
3. **Check browser console** for error messages (F12 → Console tab)
4. **Try incognito/private browsing mode**

### Platform Detection Issues

#### Problem: "Unable to detect your operating system" or wrong platform detected

**Solutions:**
1. **Manual selection**: Choose your platform from the dropdown menu
2. **Browser compatibility**: Try a different browser
3. **User agent issues**: Some privacy tools modify user agent strings
   - Temporarily disable privacy extensions
   - Use browser's standard mode (not strict privacy mode)

#### Problem: No download options shown for my platform

**Solutions:**
1. **Supported platforms**: Ensure you're using Windows, Linux, or macOS
2. **Browser compatibility**: Use a modern browser (Chrome 90+, Firefox 88+, Safari 14+)
3. **JavaScript enabled**: Ensure JavaScript is enabled in your browser

### Download Issues

#### Problem: Download fails or doesn't start

**Solutions:**
1. **Browser settings**:
   - Allow downloads from cloudtolocalllm.online
   - Check if downloads are blocked by browser settings
   - Disable popup blockers for this site

2. **Network issues**:
   - Try downloading with a different browser
   - Use a different internet connection
   - Disable VPN or proxy temporarily

3. **File size**: Ensure you have enough disk space (50+ MB free)

4. **Alternative download**:
   - Try the alternative download option (ZIP instead of MSI, etc.)
   - Use the dedicated download page: cloudtolocalllm.online/downloads

#### Problem: Downloaded file is corrupted or won't open

**Solutions:**
1. **Re-download**: Delete the file and download again
2. **Antivirus interference**: 
   - Temporarily disable real-time scanning
   - Add cloudtolocalllm.online to antivirus whitelist
   - Check quarantine folder for the downloaded file

3. **File integrity**: 
   - Compare file size with what's shown on download page
   - Try downloading with a different browser

### Installation Issues

#### Windows Installation Problems

**Problem: "Windows protected your PC" or "Unknown publisher" warning**

**Solutions:**
1. **Run anyway**: Click "More info" → "Run anyway"
2. **Right-click method**: Right-click installer → "Run as administrator"
3. **Windows Defender**: Add exception in Windows Security settings
4. **Alternative**: Use the portable ZIP version instead

**Problem: MSI installer fails with error codes**

**Solutions:**
1. **Administrator rights**: Right-click installer → "Run as administrator"
2. **Windows Installer service**: 
   - Press Win+R → type "services.msc"
   - Find "Windows Installer" → Right-click → "Start"
3. **Clean boot**: Restart Windows in clean boot mode and try again
4. **Alternative**: Use portable ZIP version

**Problem: Portable ZIP version won't run**

**Solutions:**
1. **Extract fully**: Ensure all files are extracted from ZIP
2. **Antivirus**: Check if executable is quarantined
3. **Permissions**: Right-click executable → Properties → Unblock
4. **Dependencies**: Install Visual C++ Redistributable if prompted

#### Linux Installation Problems

**Problem: AppImage won't run or "Permission denied"**

**Solutions:**
1. **Make executable**:
   ```bash
   chmod +x CloudToLocalLLM-*.AppImage
   ```

2. **FUSE requirement**:
   ```bash
   # Ubuntu/Debian
   sudo apt install fuse libfuse2
   
   # Fedora/CentOS
   sudo dnf install fuse fuse-libs
   ```

3. **Run directly**:
   ```bash
   ./CloudToLocalLLM-*.AppImage
   ```

4. **Extract and run**:
   ```bash
   ./CloudToLocalLLM-*.AppImage --appimage-extract
   ./squashfs-root/AppRun
   ```

**Problem: DEB package installation fails**

**Solutions:**
1. **Install with dependencies**:
   ```bash
   sudo dpkg -i cloudtolocalllm_*.deb
   sudo apt-get install -f
   ```

2. **Repository update**:
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

3. **Manual dependency resolution**:
   ```bash
   sudo apt install libgtk-3-0 libwebkit2gtk-4.0-37
   ```

#### macOS Installation Problems

**Problem: "App can't be opened because it is from an unidentified developer"**

**Solutions:**
1. **System Preferences method**:
   - System Preferences → Security & Privacy
   - Click "Open Anyway" next to the blocked app

2. **Right-click method**:
   - Right-click the app → "Open"
   - Click "Open" in the confirmation dialog

3. **Terminal method**:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/CloudToLocalLLM.app
   ```

**Problem: DMG won't mount or is corrupted**

**Solutions:**
1. **Re-download**: Download the DMG file again
2. **Disk Utility**: Open Disk Utility → Images → Verify
3. **Terminal mount**:
   ```bash
   hdiutil attach CloudToLocalLLM.dmg
   ```

### Connection and Tunnel Issues

#### Problem: "Unable to establish tunnel connection"

**Solutions:**
1. **Desktop client status**:
   - Ensure desktop client is running
   - Check system tray for CloudToLocalLLM icon
   - Restart desktop client if needed

2. **Firewall settings**:
   - Allow CloudToLocalLLM through Windows Firewall
   - Check router firewall settings
   - Temporarily disable firewall to test

3. **Port availability**:
   - Ensure ports 8080-8090 are not blocked
   - Close other applications using these ports
   - Try restarting your computer

4. **Network configuration**:
   - Disable VPN temporarily
   - Try different network (mobile hotspot)
   - Check proxy settings in browser

#### Problem: "Desktop client not responding"

**Solutions:**
1. **Restart desktop client**:
   - Close from system tray
   - Launch again from Start Menu/Applications

2. **Check process**:
   - Windows: Task Manager → Look for CloudToLocalLLM
   - Linux: `ps aux | grep cloudtolocalllm`
   - macOS: Activity Monitor → Search for CloudToLocalLLM

3. **Reinstall desktop client**:
   - Uninstall current version
   - Download and install fresh copy

4. **Log files**:
   - Check desktop client logs for errors
   - Windows: `%APPDATA%\CloudToLocalLLM\logs\`
   - Linux: `~/.local/share/CloudToLocalLLM/logs/`
   - macOS: `~/Library/Application Support/CloudToLocalLLM/logs/`

### Local LLM Connection Issues

#### Problem: "Local LLM not responding" or "Connection to Ollama failed"

**Solutions:**
1. **Verify Ollama is running**:
   ```bash
   ollama list
   curl http://localhost:11434/api/tags
   ```

2. **Start Ollama service**:
   ```bash
   ollama serve
   ```

3. **Check Ollama port**:
   - Default port is 11434
   - Ensure no other service is using this port
   - Try `netstat -an | grep 11434`

4. **Model availability**:
   ```bash
   ollama pull llama2  # or your preferred model
   ollama run llama2 "Hello"  # test model
   ```

5. **Firewall and network**:
   - Allow Ollama through firewall
   - Check if localhost/127.0.0.1 is accessible
   - Try different model if current one is unresponsive

#### Problem: "Streaming test failed"

**Solutions:**
1. **Model performance**: Try a smaller/faster model for testing
2. **System resources**: Ensure sufficient RAM and CPU available
3. **Ollama configuration**: Check Ollama settings and logs
4. **Network latency**: Test with local network only (disable VPN)

### Validation and Testing Issues

#### Problem: Setup validation fails with multiple errors

**Solutions:**
1. **Step-by-step verification**:
   - Manually test each component
   - Desktop client → Local LLM → Web app

2. **Restart everything**:
   - Close desktop client
   - Restart Ollama
   - Refresh web browser
   - Start desktop client
   - Re-run validation

3. **Check system resources**:
   - Ensure sufficient RAM (4GB+ recommended)
   - Close unnecessary applications
   - Check CPU usage

4. **Network stability**:
   - Use wired connection if possible
   - Disable bandwidth-heavy applications
   - Test during low-usage hours

## Browser-Specific Issues

### Chrome/Chromium
- **Downloads blocked**: chrome://settings/content/downloads
- **JavaScript disabled**: chrome://settings/content/javascript
- **Extensions interfering**: Try incognito mode

### Firefox
- **Downloads blocked**: about:preferences#privacy → Permissions
- **JavaScript disabled**: about:config → javascript.enabled
- **Strict privacy**: Disable Enhanced Tracking Protection temporarily

### Safari
- **Downloads blocked**: Safari → Preferences → Websites → Downloads
- **JavaScript disabled**: Safari → Preferences → Security
- **Cross-site tracking**: Disable "Prevent cross-site tracking" temporarily

### Edge
- **Downloads blocked**: edge://settings/content/downloads
- **SmartScreen**: Temporarily disable SmartScreen filter
- **Extensions**: Try InPrivate browsing mode

## System Requirements

### Minimum Requirements
- **RAM**: 4GB (8GB recommended)
- **Storage**: 100MB for desktop client + space for models
- **Network**: Stable internet connection (1 Mbps minimum)
- **OS**: Windows 10+, Ubuntu 18.04+, macOS 10.14+

### Recommended Requirements
- **RAM**: 8GB+ (for larger models)
- **Storage**: 10GB+ (for multiple models)
- **Network**: Broadband connection (10+ Mbps)
- **CPU**: Multi-core processor for better performance

## Getting Additional Help

### Self-Help Resources
1. **FAQ Section**: Check the FAQ in web app settings
2. **Documentation**: Visit docs.cloudtolocalllm.online
3. **Community Forum**: Join our community discussions
4. **Video Tutorials**: Watch setup videos on our YouTube channel

### Contacting Support
1. **In-App Support**: Use the help button in the web application
2. **Email Support**: support@cloudtolocalllm.online
3. **GitHub Issues**: Report bugs on our GitHub repository
4. **Discord Community**: Join our Discord server for real-time help

### Information to Include When Contacting Support
- **Operating System**: Version and architecture (32/64-bit)
- **Browser**: Name and version
- **Error Messages**: Exact text of any error messages
- **Steps to Reproduce**: What you were doing when the issue occurred
- **Screenshots**: Visual evidence of the problem
- **Log Files**: Desktop client logs if available

## Preventive Measures

### Regular Maintenance
1. **Keep software updated**: Update browser, OS, and desktop client regularly
2. **Clear browser data**: Periodically clear cache and cookies
3. **Monitor system resources**: Ensure adequate RAM and storage
4. **Update Ollama**: Keep your local LLM software current

### Best Practices
1. **Stable network**: Use reliable internet connection for setup
2. **Close unnecessary apps**: Free up system resources during setup
3. **Backup settings**: Export configuration after successful setup
4. **Test regularly**: Periodically verify your connection is working

### Security Considerations
1. **Firewall exceptions**: Only allow necessary ports
2. **Antivirus whitelist**: Add CloudToLocalLLM to trusted applications
3. **Network security**: Use secure networks for initial setup
4. **Regular updates**: Keep all components updated for security patches

Remember: Most setup issues are temporary and can be resolved with patience and systematic troubleshooting. If you're stuck, don't hesitate to reach out for help!