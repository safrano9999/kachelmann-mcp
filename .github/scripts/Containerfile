# syntax=docker/dockerfile:1.7
# Source of truth: SCRIPTS/githubactions. Generated copies are overwritten.
FROM scratch AS python-trust
ADD --checksum=sha256:fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70 \
    https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl /pip-26.2.2-py3-none-any.whl
ADD --checksum=sha256:42d35340cc5b9ba78e818ddbff0c5b1c2b779de448a340fd1b989f5fa8670e1b \
    https://files.pythonhosted.org/packages/c4/51/29046e48f693c54e5b7412216d447a1d8362c9653148d98c02cdf65fa733/certifi-2026.10.19-py3-none-any.whl /certifi-2026.10.19-py3-none-any.whl

FROM docker.io/library/python:3.13-alpine3.24@sha256:c50ccfb66e5cc97a610dcd0b9597de6ef5b52c96280b51997b353a0fc87a8361

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
      'ca-certificates>=20261020-r0' 'ca-certificates-bundle>=20261020-r0' \
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

RUN --mount=type=bind,from=python-trust,target=/tmp/python-trust \
    set -eux; \
    python -m pip install --no-index --upgrade /tmp/python-trust/*.whl; \
    python -m pip install --no-cache-dir -r /tmp/kachelmann-requirements.txt; \
    apk del .build-deps; \
    python -m pip check; \
    python -c "import pip, certifi, pip._vendor.certifi as bundled; assert pip.__version__ == '26.2.2'; assert certifi.__version__ == '2026.10.19'; assert bundled.__version__ == '2026.10.19'"; \
    python -c "import ssl; certs = ssl.create_default_context().get_ca_certs(); names = {v for c in certs for rdn in c['subject'] for k, v in rdn if k == 'commonName'}; assert len(certs) > 50; assert {'emSign ECC Root CA - G3', 'AAA Certificate Services', 'emSign Root CS CA - G3'}.isdisjoint(names)"

COPY python_header.py config.json KACHELMANN_SOT.md prompt.md package.json release.json ./
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
