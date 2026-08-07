FROM docker.io/library/python:3.13-alpine3.22@sha256:e81548ac35b07a3bd4805f275107592ef458b1e893c0e04d45aedaa19416cca5

ARG KACHELMANN_SOURCE_REVISION=unknown

LABEL org.opencontainers.image.title="KACHELMANN MCP" \
      org.opencontainers.image.description="Authenticated Streamable HTTP MCP interface for KACHELMANN" \
      org.opencontainers.image.source="https://github.com/safrano9999/kachelmann-mcp" \
      org.opencontainers.image.revision="${KACHELMANN_SOURCE_REVISION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    KACHELMANN_MCP_ENABLED=true \
    KACHELMANN_MCP_HOST=0.0.0.0 \
    KACHELMANN_MCP_PORT=8005

WORKDIR /opt/kachelmann

RUN set -eux; \
    apk add --no-cache \
      ca-certificates \
      freetype \
      libjpeg-turbo \
      libpq \
      libwebp \
      tzdata \
      zlib; \
    apk add --no-cache --virtual .build-deps \
      build-base \
      freetype-dev \
      libjpeg-turbo-dev \
      libwebp-dev \
      postgresql-dev \
      zlib-dev

COPY requirements.txt /tmp/kachelmann-requirements.txt

RUN set -eux; \
    python -m pip install --no-cache-dir --upgrade pip; \
    python -m pip install --no-cache-dir -r /tmp/kachelmann-requirements.txt; \
    apk del .build-deps; \
    python -m pip check

COPY python_header.py config.json KACHELMANN_SOT.md prompt.md ./
COPY kachelmann ./kachelmann
COPY COACHING_ADVISES ./COACHING_ADVISES
COPY static/favicon.svg ./static/favicon.svg
COPY static/fonts ./static/fonts

RUN set -eux; \
    addgroup -S -g 10001 kachelmann; \
    adduser -S -D -H -u 10001 -G kachelmann kachelmann; \
    mkdir -p /data; \
    chown -R kachelmann:kachelmann /opt/kachelmann /data

USER 10001:10001

EXPOSE 8005

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c 'import os; from urllib.request import urlopen; port = os.environ.get("KACHELMANN_MCP_PORT", "8005"); urlopen(f"http://127.0.0.1:{port}/", timeout=3).read()'

ENTRYPOINT ["python", "-m", "kachelmann.mcp_server"]
CMD ["--transport", "streamable-http"]
