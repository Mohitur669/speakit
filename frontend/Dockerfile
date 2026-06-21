# Stage 1 — Build Angular
FROM node:22.11.0-alpine3.20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
RUN npm run prebuild && npm run build

# Stage 2 — Serve with nginx
FROM nginx:1.25.3-alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html
EXPOSE 80
