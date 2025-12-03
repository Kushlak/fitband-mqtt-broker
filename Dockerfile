# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci

COPY tsconfig*.json nest-cli.json ./
COPY src ./src
COPY prisma ./prisma

RUN npm run build

# --- Runtime stage ---
FROM node:20-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup -S app && adduser -S app -G app
USER app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist
COPY prisma ./prisma

EXPOSE 8080

CMD ["node", "dist/main.js"]
