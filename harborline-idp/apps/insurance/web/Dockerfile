# syntax=docker/dockerfile:1.7
# Web tier: build with Node, serve static assets from unprivileged NGINX (uid 101, port 8080, read-only rootfs).
ARG NODE_IMAGE=node:22-alpine
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.27-alpine

FROM ${NODE_IMAGE} AS build
WORKDIR /src
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --ignore-scripts; else npm install --ignore-scripts; fi
COPY . .
RUN npm run build

FROM ${NGINX_IMAGE} AS runtime
LABEL org.opencontainers.image.source="https://github.com/harborline/harborline-idp" \
      org.opencontainers.image.title="policy-portal-web"
USER root
RUN rm -f /etc/nginx/conf.d/default.conf && apk upgrade --no-cache
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/templates/ /etc/nginx/templates/
COPY --from=build /src/dist /usr/share/nginx/html
# Templates render into /tmp (emptyDir) so the root filesystem can stay read-only.
ENV NGINX_ENVSUBST_OUTPUT_DIR=/tmp \
    NGINX_ENVSUBST_FILTER=^WEB_
USER 101
EXPOSE 8080
