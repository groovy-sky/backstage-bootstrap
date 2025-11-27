# Multi-stage Dockerfile to build and run the Backstage backend
# IMPORTANT:
#   - Build context can be the repository root; set APP_DIR to your Backstage app path relative to the context
#   - Example:
#       docker build -f backstage/Dockerfile -t backstage:latest --build-arg APP_DIR=backstage-app .

########################################
# Builder stage
########################################
FROM node:20-bookworm-slim AS builder
ARG APP_DIR=backstage-app

# Install sqlite3 dependencies and techdocs build deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libsqlite3-dev python3 python3-pip python3-venv build-essential && \
    corepack enable && \
    yarn config set python /usr/bin/python3

# Set up a virtual environment for mkdocs-techdocs-core (for any build-time use)
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip3 install mkdocs-techdocs-core==1.1.7

WORKDIR /app

# ---- Copy application source ----
COPY ${APP_DIR}/ ./

ENV NODE_ENV=development
ENV CI=true

# Install dependencies (non-interactive)
RUN corepack prepare yarn@4.4.1 --activate

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,sharing=locked,uid=1000,gid=1000 \
  yarn install --immutable

# ---- Build backend ----

# Compile TS and build backend; all inside Docker
RUN yarn tsc
RUN yarn build:backend --config /app/app-config.yaml --config /app/app-config.production.yaml

# Extract backend bundle tarballs so runtime image can run directly
RUN cd /app && \
  tar xzf packages/backend/dist/bundle.tar.gz && \
  tar xzf packages/backend/dist/skeleton.tar.gz && \
  rm packages/backend/dist/bundle.tar.gz packages/backend/dist/skeleton.tar.gz

########################################
# Runtime stage
########################################
FROM node:20-bookworm-slim

# Install sqlite3 dependencies and techdocs deps (runtime)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libsqlite3-dev python3 python3-pip python3-venv build-essential && \
    yarn config set python /usr/bin/python3

# Set up a virtual environment for mkdocs-techdocs-core.
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip3 install mkdocs-techdocs-core==1.1.7

WORKDIR /app

# Run as non-root
RUN useradd --user-group --create-home --shell /bin/false appuser && chown appuser:appuser /app
USER appuser

ENV NODE_ENV=production

# Copy production runtime files from builder

# Root package + lockfile
COPY --from=builder /app/package.json /app/yarn.lock ./

# Node modules (production deps only would be better, but this is simplest & robust;
# you can refine later using yarn workspaces focus --production in builder)
COPY --from=builder /app/node_modules ./node_modules

# Backend dist
COPY --from=builder /app/packages/backend/dist ./packages/backend/dist
COPY --from=builder /app/packages/backend/package.json ./packages/backend/package.json

# Frontend package metadata and static assets required by backend (plugins expect workspace "app")
COPY --from=builder /app/packages/app/package.json ./packages/app/package.json
COPY --from=builder /app/packages/app/dist ./packages/app/dist

# Catalog example data referenced by production config
COPY --from=builder /app/examples ./examples

# Config files (non-interactive runtime configuration)
COPY --from=builder /app/app-config*.yaml ./

EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
