# CloudToLocalLLM Complete Deployment Workflow

This is the **ONE AND ONLY** deployment document for CloudToLocalLLM. Follow this exactly to ensure a smooth and successful deployment.

**Estimated Total Time:** 45-90 minutes

**⚠️ IMPORTANT NOTICE**: AUR (Arch User Repository) support has been temporarily removed as of v3.10.3. See [AUR Status Documentation](./AUR_STATUS.md) for complete details and reintegration timeline.

**Related Documentation:**
- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
- [Simplified Tunnel Architecture](../ARCHITECTURE/SIMPLIFIED_TUNNEL_ARCHITECTURE.md)
- [Versioning Strategy](./VERSIONING_STRATEGY.md)

---

## 🔍 **Phase 1: Pre-Flight Checks** (5 minutes)

**MANDATORY: Complete ALL checks before starting deployment**

### **Environment Verification**
```bash
# 1. Verify you're in the correct directory
pwd
# Expected: /path/to/CloudToLocalLLM

# 2. Check Git status
git status
# Expected: "working tree clean" or only untracked files

# 3. Verify Flutter installation
flutter --version
# Expected: Flutter 3.x.x or higher

# 4. Check version manager script
./scripts/version_manager.sh help
# Expected: Help output with commands listed

# 5. Verify current version
./scripts/version_manager.sh info
# Expected: Current version information display
```

### **Required Tools Checklist**
- [ ] Flutter SDK installed and in PATH
- [ ] Git configured with proper credentials
- [ ] SSH access to VPS (test: `ssh cloudllm@cloudtolocalllm.online "echo 'Connection OK'"`)

---

## 📋 **Phase 2: Version Management** (5 minutes)

### **Manual Version Increment Process**
**Performed AFTER deployment verification**
```powershell
# Use the PowerShell version manager script - ALWAYS
./scripts/powershell/version_manager.ps1 increment <type>

# Types:
# - major: Creates GitHub release (x.0.0) - significant changes
# - minor: Feature additions (x.y.0) - no GitHub release
# - patch: Bug fixes (x.y.z) - no GitHub release

# Commit version changes
git add . && git commit -m "Increment version after deployment"

# Push using native git command
git push origin master
```

---

## 🔄 **Phase 3: Build & Package Creation** (15-25 minutes)

### **Step 3.1: Clean Build Environment**
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Verify no dependency issues
flutter doctor
```

### **Step 3.2: Build Flutter Applications**
```bash
# For web deployment (VPS)
flutter build web --release --no-tree-shake-icons

# For desktop deployment (Linux)
./scripts/build_unified_package.sh
```

---

## 🚀 **Phase 4: VPS Deployment** (10-15 minutes)

### **Step 4.1: Deploy to VPS**
```bash
# SSH to VPS as cloudllm user
ssh cloudllm@cloudtolocalllm.online

# Navigate to project directory
cd /opt/cloudtolocalllm

# Pull latest changes
git pull origin master

# Run deployment script
./scripts/deploy/update_and_deploy.sh
```

### **Step 4.2: Verify VPS Deployment**
```bash
# Check container status
docker compose ps

# Test main application
curl -I https://app.cloudtolocalllm.online
# Expected: HTTP/1.1 200 OK

# Check version endpoint
curl -s https://app.cloudtolocalllm.online/version.json
```

---

## ✅ **Phase 5: Comprehensive Verification** (10 minutes)

### **Automated Verification Script**
```bash
# Run comprehensive verification
./scripts/deploy/verify_deployment.sh
```

### **Manual Verification**
- **Desktop Application:** Launches without errors, connects to local Ollama.
- **Web Application:** Loads correctly, authentication works, no console errors.

---

## 🚫 **Deployment Completion Criteria**

- **Version Consistency:** All components show the identical version number.
- **All Components Deployed:** Git repo updated, packages created, VPS deployed.
- **Comprehensive Testing Completed:** All automated and manual tests passed.

---

## 🔧 **Troubleshooting**

- **Version Mismatch:** Run `./scripts/deploy/sync_versions.sh` on the VPS.
- **VPS Deployment Issues:** Check container logs with `docker compose logs webapp --tail 50`.
- **SSH/Access Issues:** Test SSH connection with `ssh -v cloudllm@cloudtolocalllm.online`.