# syntax=docker/dockerfile:1.7
ARG PYTHON_IMAGE=python:3.12-slim-bookworm

FROM ${PYTHON_IMAGE} AS build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.txt requirements.lock* ./
RUN python -m venv /opt/venv \
 && if [ -f requirements.lock ]; then /opt/venv/bin/pip install --require-hashes -r requirements.lock; \
    else /opt/venv/bin/pip install -r requirements.txt; fi
COPY src ./src

FROM ${PYTHON_IMAGE} AS runtime
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /opt/venv /opt/venv
COPY --from=build /build/src /app/src
ENV PATH=/opt/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH=/app/src \
    OTEL_SEMCONV_STABILITY_OPT_IN=http
WORKDIR /app
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["uvicorn", "${{ values.package }}.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-server-header", "--no-access-log"]
