# Multi-stage Dockerfile to build and run the Backstage backend
# IMPORTANT:
#   - Build context MUST be the Backstage app root, e.g. "backstage-app/"
#   - Example:
#       cd backstage-app
#       docker build -f ../backstage/Dockerfile -t backstage:latest .

########################################
# Builder stage
########################################
FROM node:20-bookworm-slim AS builder

# Install sqlite3 dependencies and techdocs build deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libsqlite3-dev python3 python3-pip python3-venv build-essential && \
    yarn config set python /usr/bin/python3

# Set up a virtual environment for mkdocs-techdocs-core (for any build-time use)
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip3 install mkdocs-techdocs-core==1.1.7

WORKDIR /app

# ---- Install dependencies (using Yarn Berry if present) ----

# Copy Yarn Berry config if it exists in the app (typical Backstage app)
# If your app doesn't use .yarn, comment these two lines and adjust the install below.
COPY .yarn ./.yarn
COPY .yarnrc.yml ./

# Copy root manifest and lockfile
COPY package.json yarn.lock ./

# Copy backend package manifest so workspaces can resolve it
COPY packages/backend/package.json packages/backend/

# If backend depends on other workspaces, copy their manifests too, e.g.:
# COPY packages/*/package.json packages/*/

ENV NODE_ENV=development
ENV CI=true

# Install dependencies (non-interactive)
RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable

# ---- Build backend ----

# Now copy the rest of the app source (ts, configs, etc.)
COPY . .

# Compile TS and build backend; all inside Docker
RUN yarn tsc
RUN yarn build:backend

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

# Config files (non-interactive runtime configuration)
COPY --from=builder /app/app-config*.yaml ./

EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml"]
