# syntax=docker/dockerfile:1.7
# Golden-path Python image: multi-stage, hash-locked deps when available, non-root (10001), no shell entrypoint.
# Base images are pinned by digest by Dependabot/Renovate (`FROM image@sha256:...`) after `make pin-images`.
ARG PYTHON_IMAGE=python:3.12-slim-bookworm

FROM ${PYTHON_IMAGE} AS build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.txt requirements.lock* ./
RUN python -m venv /opt/venv \
 && if [ -f requirements.lock ]; then /opt/venv/bin/pip install --require-hashes -r requirements.lock; \
    else /opt/venv/bin/pip install -r requirements.txt; fi
COPY pyproject.toml ./
COPY src ./src
RUN /opt/venv/bin/pip install --no-deps . && /opt/venv/bin/python -m compileall -q /opt/venv

FROM ${PYTHON_IMAGE} AS runtime
LABEL org.opencontainers.image.source="https://github.com/harborline/harborline-idp" \
      org.opencontainers.image.title="claims-worker" \
      org.opencontainers.image.vendor="Harborline Insurance"
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OTEL_SEMCONV_STABILITY_OPT_IN=http
WORKDIR /app
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["python", "-m", "claims_worker.main"]
