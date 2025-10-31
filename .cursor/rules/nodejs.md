# Node.js Best Practices

## Dependency Management

- Use `npm ci` for production builds (faster, more reliable than `npm install`).
- Use `npm install` for development (updates package.json and package-lock.json).
- Never manually edit `package-lock.json`, let npm manage it.
- Keep dependencies up to date with `npm outdated` and `npm update`.

## Security

- Run as non-root user in Docker containers (UID 1001 for Node.js apps).
- Use `npm audit` to check for vulnerabilities.
- Never hardcode secrets or API keys, use environment variables.
- Validate and sanitize all user inputs.

## Code Quality

- Use structured logging (e.g., `winston`, `pino`) instead of `console.log`.
- Implement proper error handling with try-catch blocks.
- Use async/await instead of callbacks when possible.
- Follow ESLint rules and fix linting errors before committing.

## API Development

- Use Express.js middleware for authentication (e.g., `express-oauth2-jwt-bearer` for Auth0).
- Implement proper CORS configuration for web clients.
- Use environment variables for configuration (domain, audience, client IDs).
- Validate JWT tokens before processing requests.

## Performance

- Use connection pooling for databases.
- Implement request rate limiting.
- Use compression middleware (e.g., `compression` package).
- Cache static assets when appropriate.

## Error Handling Pattern

```javascript
try {
  // async operation
  const result = await someAsyncOperation();
  return result;
} catch (error) {
  logger.error('Operation failed', { error, context });
  throw new Error('User-friendly error message');
}
```

