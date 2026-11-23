# Imagen de producción del backend (incluye las migraciones de db/).
# Se construye desde la RAÍZ del repositorio:
#   docker build -f backend/Dockerfile -t faithbridge-backend .
FROM node:22-slim AS build
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
RUN npm ci
COPY backend/tsconfig.json ./
COPY backend/src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-slim
ENV NODE_ENV=production \
    DB_DIR=/app/db
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY backend/package.json ./
COPY db/migrations ./db/migrations
USER node
EXPOSE 8080
CMD ["node", "dist/server.js"]
