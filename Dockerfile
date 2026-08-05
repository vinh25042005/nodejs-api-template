# ─── Build stage ────────────────────────────────────────────────
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# ─── Runtime stage (non-root, fail-securely) ───────────────────
# Lý do:
#   - Chạy non-root (USER app) → nếu bị RCE, attacker không có quyền root
#   - dumb-init → nhận signal đúng để pod graceful shutdown khi scale/rollout
#   - apk upgrade → patch CVE OS (openssl) của base image
#   - rm npm → runtime chỉ cần node, bỏ npm giảm attack surface
#     và hết các CVE npm-bundled bị Trivy quét
FROM node:24-alpine
ENV NODE_ENV=production \
    PORT=8080
LABEL org.opencontainers.image.title="nodejs-api" \
      org.opencontainers.image.version="0.1.0"
RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init && \
    rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm /usr/local/bin/npx && \
    addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build --chown=app:app /app ./
USER app
EXPOSE 8080
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
