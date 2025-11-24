# Gray Screen Fix - Deployment Checklist

## Pre-Deployment Verification

- [ ] All code changes reviewed and tested locally
- [ ] No new linter errors or warnings
- [ ] Sentry DSN is correctly configured
- [ ] Flutter web build completes successfully
- [ ] Docker image builds without errors

## Build Steps

```bash
# 1. Clean previous builds
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build web app
flutter build web --release

# 4. Verify build output
ls -la build/web/
```

## Docker Build

```bash
# Build with cache busting
docker build \
  --build-arg BUILD_SHA=$(git rev-parse --short HEAD) \
  -f config/docker/Dockerfile.web \
  -t cloudtolocalllm/cloudtolocalllm-web:latest \
  .
```

## Deployment

- [ ] Push Docker image to Docker Hub
- [ ] Update AKS deployment with new image
- [ ] Monitor rollout status
- [ ] Verify app loads without gray screen
- [ ] Check browser console for errors
- [ ] Monitor Sentry for new issues

## Post-Deployment Verification

### Browser Testing
- [ ] App loads on https://app.cloudtolocalllm.online
- [ ] No gray screen appears
- [ ] Loading screen displays correctly
- [ ] Login screen appears after loading
- [ ] Theme loads correctly (dark/light mode)

### Console Checks
- [ ] No "Provider not found" errors
- [ ] No "Null check operator" errors
- [ ] Service registration logs appear
- [ ] Auth0 initialization logs appear

### Sentry Monitoring
- [ ] No new "Provider not found" errors
- [ ] Error rate returns to normal
- [ ] No increase in crash reports
- [ ] Check error trends over 24 hours

## Rollback Plan

If issues occur:

```bash
# Rollback to previous image
kubectl set image deployment/cloudtolocalllm-web \
  cloudtolocalllm-web=cloudtolocalllm/cloudtolocalllm-web:previous-tag \
  -n default

# Monitor rollout
kubectl rollout status deployment/cloudtolocalllm-web
```

## Monitoring Commands

```bash
# Check pod status
kubectl get pods -l app=cloudtolocalllm-web

# View pod logs
kubectl logs -f deployment/cloudtolocalllm-web

# Check service status
kubectl get svc cloudtolocalllm-web

# Monitor events
kubectl get events --sort-by='.lastTimestamp'
```

## Success Criteria

✓ App loads without gray screen
✓ No "Provider not found" errors in Sentry
✓ No console errors in browser
✓ Authentication flow works correctly
✓ Theme provider works correctly
✓ All services initialize properly
