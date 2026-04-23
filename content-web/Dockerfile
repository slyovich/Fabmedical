FROM node:dubnium AS build
WORKDIR /usr/src/app

RUN npm install -g @angular/cli@~8.3.4

# Install full dependency tree for Angular build.
COPY package*.json ./
RUN npm ci

# Build front-end in production mode to reduce startup payload.
COPY . .
RUN npm run build -- --configuration production

FROM node:dubnium-alpine AS final
WORKDIR /usr/src/app

RUN apk add --no-cache curl

ARG BUILD_VERSION
ENV BUILD_VERSION=${BUILD_VERSION}
ENV NODE_ENV=production

# Install only runtime dependencies for a smaller final image.
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --from=build /usr/src/app/dist ./dist
COPY --from=build /usr/src/app/app.js ./app.js

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
	CMD curl -fsS http://127.0.0.1:${PORT:-3000}/api/version || exit 1

CMD ["node", "app.js"]
