# syntax=docker/dockerfile:1.7
# Backstage image (multi-stage, builds inside Docker). TechDocs uses the local generator, so mkdocs-techdocs-core
# is installed in a dedicated venv. Runs as the non-root `node` user with a read-only root filesystem.
ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${NODE_IMAGE} AS build
WORKDIR /app
ENV CI=true
RUN corepack enable
COPY package.json yarn.lock* backstage.json tsconfig.json ./
COPY packages packages
RUN if [ -f yarn.lock ]; then yarn install --immutable; else yarn install; fi
RUN yarn tsc && yarn build:backend

FROM ${NODE_IMAGE} AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv g++ make libsqlite3-dev \
 && python3 -m venv /opt/techdocs && /opt/techdocs/bin/pip install --no-cache-dir "mkdocs-techdocs-core>=1.4,<2" \
 && rm -rf /var/lib/apt/lists/*
ENV PATH=/opt/techdocs/bin:$PATH NODE_ENV=production NODE_OPTIONS="--no-node-snapshot"
WORKDIR /app
RUN corepack enable && chown node:node /app
USER node
COPY --chown=node:node --from=build /app/yarn.lock* /app/package.json /app/backstage.json ./
COPY --chown=node:node --from=build /app/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz
RUN if [ -f yarn.lock ]; then yarn workspaces focus --all --production; else yarn install; fi && yarn cache clean
COPY --chown=node:node --from=build /app/packages/backend/dist/bundle.tar.gz ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz
COPY --chown=node:node app-config.yaml app-config.production.yaml ./
EXPOSE 7007
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
