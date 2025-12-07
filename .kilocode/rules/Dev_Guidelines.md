# Development Guidelines

## Project Structure & Module Organization
- `lib/` contains the Flutter app (screens, services, widgets); `web/` holds Flutter web config; `assets/` stores static media and version metadata.
- `services/api-backend/` is the Node/Express API; `services/streaming-proxy/` handles the proxy runtime; `services/sdk/` ships client helpers; `services/postgres/` covers database support.
- `scripts/` and `build-tools/` manage packaging and installers; `infra/`, `k8s/`, and `config/` house deployment manifests and shared configuration.
- Tests: `test/` (unit/widget/integration plus Playwright helpers), backend Jest specs in `test/api-backend` and `services/api-backend/test`, and sample Playwright E2E in `e2e/`.

## Build, Test, and Development Commands
- Flutter: `flutter pub get`; dev web via `./run_dev.sh` (Chrome on :3000) or desktop with `flutter run -d linux`; format/lint using `dart format lib test` and `flutter analyze`.
- Flutter tests: `flutter test` for unit/widget; narrow scope with `flutter test test/widgets/widget_test.dart`.
- Backend (from `services/api-backend`): `npm install`, `npm run dev` (nodemon), `npm start`, `npm test`, and `npm test -- --coverage`.
- Playwright: `npx playwright install` once, then `npx playwright test e2e` for smoke checks.

## Coding Style & Naming Conventions
- Dart/Flutter: 2-space indent, `PascalCase` classes/widgets, `snake_case` files, prefer const widgets and typed services; document public APIs when behavior is non-obvious.
- JavaScript backend: ES modules (`import`/`export`), `camelCase` functions, `SCREAMING_SNAKE_CASE` env vars; keep middleware ordering explicit.
- Configuration comes from `.env` (copy `env.template`); do not commit secrets or generated binaries.

## Testing Guidelines
- Jest matches `**/test/**/*.test.js`; keep mocks local to specs and reset state per test.
- Flutter tests live in `test/` with `*_test.dart`; favor widget/golden coverage for UI and integration coverage for tunnel/auth flows.
- Add at least one automated check per feature and avoid regressing coverage on `services/**` (Jest collects from there).

## Commit & Pull Request Guidelines
- Use the conventional prefixes seen in history (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`); keep subjects imperative and under ~70 chars.
- PRs should include a short summary, how to run/verify (commands above), linked issue/ticket, and screenshots or logs for UX/back-end changes.
- Note configuration/env var changes or migrations in the PR and update `docs/` when user-facing behavior shifts.

## Security & Configuration Tips
- Rotate secrets via env vars; never hardcode DSNs or tokens in code or tests.
- Keep Sentry/remote calls toggleable via config, prefer localhost defaults for development, and avoid exposing debug ports publicly.