# ── Build stage: compile React into static files ──────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --silent

COPY public ./public
COPY src ./src

# REACT_APP_API_URL must be set at build time (build arg → env var).
# In production the ALB strips /api and routes to the backend, so the default
# of "/api" works with no extra config.
ARG REACT_APP_API_URL=/api
ENV REACT_APP_API_URL=$REACT_APP_API_URL

RUN npm run build

# ── Runtime stage: serve the build with nginx ─────────────────────────────────
FROM nginx:1.30.0-alpine

COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
