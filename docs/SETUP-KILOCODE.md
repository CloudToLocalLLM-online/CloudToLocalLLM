# Setting Up Kilo Code CLI for AI-Powered Versioning

## Get Your API Key

1. **Go to Google AI Studio**:
   - Visit: https://makersuite.google.com/app/apikey
   - Or: https://aistudio.google.com/app/apikey

2. **Create API Key**:
   - Click "Create API Key"
   - Select "Create API key in new project" (or existing project)
   - Copy the generated key

3. **Configure Kilo Code**:
   Run the setup script to configure your environment:
   ```bash
   ./scripts/setup-kilocode.sh 'your_api_key_here'
   ```

   Or manually add to GitHub Secrets:
   ```bash
   gh secret set KILOCODE_API_KEY --body 'your_api_key_here'
   ```

4. **Verify**:
   ```bash
   gh secret list | grep KILOCODE
   # Should show: KILOCODE_API_KEY
   ```

## Test Locally (Optional)

```bash
# Export your key (if not using setup script)
export KILOCODE_API_KEY='your_key_here'

# Test version analysis
./scripts/analyze-version-bump.sh

# Test version update
./scripts/update-all-versions.sh 4.5.0 $(git rev-parse --short HEAD)
```

## Fallback Behavior

If `KILOCODE_API_KEY` is not set:
- ✅ Workflow still works
- ⚠️  Defaults to PATCH bump
- ⚠️  No intelligent analysis
- 📝 Warning shown in logs

## Cost

- **Kilo Code (via Gemini API)**: Free tier includes 60 requests/minute
- **Each version bump**: 1 API call
- **Typical usage**: ~10-50 calls/month
- **Cost**: $0 (within free tier)

## Privacy

Kilo Code receives:
- ✅ Commit messages (public repo info)
- ✅ Current version number
- ❌ No source code
- ❌ No secrets
- ❌ No user data

## Alternative: Manual Versioning

If you prefer not to use Kilo Code:

```bash
# Disable version-bump workflow
# Edit .github/workflows/version-bump.yml:
# Change: if: "!contains(...)"
# To: if: false

# Manual version tagging
git tag 4.5.0-cloud-$(git rev-parse --short HEAD)
git tag 4.5.0-desktop-$(git rev-parse --short HEAD)
git tag 4.5.0-mobile-$(git rev-parse --short HEAD)
git push origin --tags
```

## Quota Limits

Google AI Studio Free Tier:
- **60 requests/minute**
- **1,500 requests/day**
- **Sufficient for**: 100+ deployments/day

If you hit limits:
- Workflow falls back to PATCH bump
- No deployment failure
- Consider upgrading to paid tier

