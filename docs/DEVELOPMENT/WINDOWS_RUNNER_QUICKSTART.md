# Windows Self-Hosted Runner Quick Start

Quick reference guide for setting up a Windows self-hosted GitHub Actions runner.

## 🚀 One-Command Setup

```powershell
# Run as Administrator
.\scripts\powershell\Setup-WindowsSelfHostedRunner.ps1
```

When prompted, enter your runner registration token from:
**GitHub → Settings → Actions → Runners → New runner**

## ✅ Verify Setup

```powershell
# Check runner service
Get-Service actions.runner.*

# Check Flutter
flutter doctor

# View runner logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 20
```

## 📍 Verify in GitHub

Visit: `https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/settings/actions/runners`

Your runner should appear with:
- ✅ Green status
- Labels: `windows`, `self-hosted`
- Name: Your computer name

## 🔄 Manage Runner

```powershell
# Restart runner service
Restart-Service actions.runner.*

# Stop runner
Stop-Service actions.runner.*

# Start runner
Start-Service actions.runner.*
```

## 📚 Full Documentation

See [WINDOWS_SELF_HOSTED_RUNNER_SETUP.md](WINDOWS_SELF_HOSTED_RUNNER_SETUP.md) for complete details.

