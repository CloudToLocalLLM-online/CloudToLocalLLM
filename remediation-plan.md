# Code Cleanup Remediation Plan

## 1. Missing Route Implementations

The following route files are not imported in `server.js` and need to be implemented:

- `services/api-backend/routes/adaptive-rate-limiting.js`
- `services/api-backend/routes/admin-metrics.js`
- `services/api-backend/routes/alert-configuration.js`
- `services/api-backend/routes/auth-audit.js`
- `services/api-backend/routes/backup-recovery.js`
- `services/api-backend/routes/bridge-polling-routes.js`
- `services/api-backend/routes/cache-metrics.js`
- `services/api-backend/routes/deprecation.js`
- `services/api-backend/routes/direct-proxy-routes.js`
- `services/api-backend/routes/error-recovery.js`
- `services/api-backend/routes/failover.js`
- `services/api-backend/routes/proxy-config.js`
- `services/api-backend/routes/proxy-diagnostics.js`
- `services/api-backend/routes/proxy-failover.js`
- `services/api-backend/routes/proxy-health.js`
- `services/api-backend/routes/proxy-metrics.js`
- `services/api-backend/routes/proxy-scaling.js`
- `services/api-backend/routes/proxy-usage.js`
- `services/api-backend/routes/proxy-webhooks.js`
- `services/api-backend/routes/quotas.js`
- `services/api-backend/routes/rate-limit-exemptions.js`
- `services/api-backend/routes/rate-limit-violations.js`
- `services/api-backend/routes/sandbox.js`
- `services/api-backend/routes/tunnel-failover.js`
- `services/api-backend/routes/tunnel-health.js`
- `services/api-backend/routes/tunnel-sharing.js`
- `services/api-backend/routes/tunnel-usage.js`
- `services/api-backend/routes/tunnel-webhooks.js`
- `services/api-backend/routes/user-activity.js`
- `services/api-backend/routes/user-deletion.js`
- `services/api-backend/routes/versioned-routes.js`
- `services/api-backend/routes/webhook-event-filters.js`
- `services/api-backend/routes/webhook-payload-transformations.js`
- `services/api-backend/routes/webhook-rate-limiting.js`
- `services/api-backend/routes/webhook-testing.js`

## 2. Unused Dependencies

The following dependencies are not used in the codebase and can be removed from `package.json`:

- `fast-check`

## 3. Refactoring Opportunities

- **Duplicate Route Registrations:** In `server.js`, many routes are registered twice, once with an `/api` prefix and once without. This can be simplified by using a single registration with an optional prefix.
- **Inline Route Handlers:** The `server.js` file contains several inline route handlers that can be extracted into separate files for better organization and maintainability.
- **Commented-Out Code:** There are several instances of commented-out code that should be reviewed and either removed or reinstated.

## 4. Proposed Actions

1. **Remove Unused Route Files:** Delete the route files listed in section 1.
2. **Remove Unused Dependencies:** Remove the unused dependencies from `package.json` and run `npm install` to update the `package-lock.json` file.
3. **Refactor Route Registrations:** Refactor the route registrations in `server.js` to eliminate duplication.
4. **Extract Inline Route Handlers:** Move the inline route handlers in `server.js` to separate files in the `routes` directory.
5. **Review Commented-Out Code:** Review and address all instances of commented-out code.