# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json .
RUN npm ci

COPY . .
RUN npm run build

# ── Stage 2: Serve ────────────────────────────────────────────────────────────
# nginx serves the static files Vite produced
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html

# Custom nginx config — needed for React Router to work correctly
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80