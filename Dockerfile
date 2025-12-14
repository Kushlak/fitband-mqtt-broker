# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app

RUN apk add --no-cache python3 make g++ openssl

COPY package*.json ./
RUN npm ci

# Install dotenv for prisma.config.ts
RUN npm install --no-save dotenv

COPY tsconfig*.json nest-cli.json ./
COPY src ./src
COPY prisma ./prisma
COPY prisma.config.ts ./

# Generate Prisma client (DATABASE_URL not needed for generate, but prisma.config.ts requires it)
# Use dummy URL since we're only generating the client, not connecting
ENV DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"
RUN npx prisma generate

# Build application
RUN npm run build

# --- Runtime stage ---
FROM node:20-alpine AS production
WORKDIR /app

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
ENV PORT=8080

# Install curl for healthcheck
RUN apk add --no-cache curl openssl

# Create app user
RUN addgroup -S app && adduser -S app -G app

# Copy package files with ownership
COPY --chown=app:app package*.json ./

# Install production dependencies
RUN npm ci --omit=dev

# Install prisma CLI, dotenv, and tsx for TypeScript config support
# Install as root before switching to app user to ensure proper installation
RUN npm install --no-save prisma dotenv@^16.0.0 tsx

# Copy Prisma files and config (needed for migrations)
COPY --chown=app:app prisma ./prisma
COPY --chown=app:app prisma.config.ts ./
COPY --chown=app:app prisma.config.js ./

# Copy build artifacts with ownership
COPY --from=build --chown=app:app /app/dist ./dist
# Copy generated Prisma client to dist structure so compiled code can find it
COPY --from=build --chown=app:app /app/generated ./generated
RUN mkdir -p dist/generated && cp -r generated dist/generated

# Create certs directory
RUN mkdir -p /app/certs && chown app:app /app/certs

USER app

EXPOSE 8080
EXPOSE 8443

# Run migrations and start app
# Use --schema flag to ensure Prisma reads DATABASE_URL from environment
CMD npx prisma migrate deploy --schema=./prisma/schema.prisma && node dist/src/main.js
