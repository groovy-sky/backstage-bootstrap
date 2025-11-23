# Multi-stage Dockerfile to build and run the Backstage backend

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

# Copy only what is needed to install dependencies first (better build cache)
COPY .yarn ./.yarn
COPY .yarnrc.yml ./
COPY package.json yarn.lock ./

# Copy the backend package.json and related workspace metadata so yarn install can run
COPY packages/backend/package.json packages/backend/
# If you have other workspaces that backend depends on, copy their package.jsons too
# COPY packages/*/package.json packages/*/

# Install dependencies in CI/non-interactive mode
ENV NODE_ENV=development
ENV CI=true

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable

# Now copy the rest of the repo (source code, configs, etc.)
COPY . .

# Build TypeScript and backend bundle
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

# From here on we use the least-privileged `node` user to run the backend.
WORKDIR /app
RUN chown node:node /app
USER node

# This switches many Node.js dependencies to production mode.
ENV NODE_ENV=production

# Copy over Yarn 3 configuration, release, and plugins
COPY --chown=node:node .yarn ./.yarn
COPY --chown=node:node .yarnrc.yml ./

# Copy repo skeleton and yarn lockfile from builder
# The skeleton is produced by `yarn build:backend` in the builder stage
COPY --chown=node:node --from=builder /app/yarn.lock /app/package.json /app/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

# Install only production dependencies focused on the workspaces we need
RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production

# Then copy the backend bundle and config files from builder
COPY --chown=node:node --from=builder /app/packages/backend/dist/bundle.tar.gz ./
COPY --chown=node:node --from=builder /app/app-config*.yaml ./

RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml"]