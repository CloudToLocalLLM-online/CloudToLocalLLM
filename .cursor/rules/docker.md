# Docker Best Practices

## Flutter Web Apps

- **Use COPY, not git clone**: Copy source files from build context using `COPY`, not `git clone`. This enables Docker layer caching and follows standard Docker practices.
- **Layer caching optimization**: Copy `pubspec.yaml` and `pubspec.lock` first, run `flutter pub get`, then copy the rest of the source. This caches dependencies unless pubspec changes.
- **No user creation**: Never create users manually. Use the default non-root user that exists in the base container (e.g., Cirrus Flutter containers already have a default non-root user).
- **Multi-stage builds**: Use separate build and runtime stages. Build with Flutter image, serve with lightweight nginx image.

### Standard Flutter Web Pattern

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM nginxinc/nginx-unprivileged:alpine
COPY --from=builder --chown=nginx:nginx /app/build/web /usr/share/nginx/html
```

- **Never run as root**: Always use the container's default non-root user. Never explicitly create users unless absolutely necessary and the container doesn't provide one.

## Node.js Apps

- **Multi-stage builds**: Build dependencies as root, then copy and run as non-root.
- **Layer caching**: Copy `package*.json` first, run `npm ci`, then copy source code.
- **Use lightweight images**: `node:24-alpine` or similar.

### Standard Node.js Pattern

```dockerfile
FROM node:24-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci && chown -R 1001:1001 /app

FROM node:24-alpine AS production
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY --from=base --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .
USER nodejs
CMD ["npm", "start"]
```

