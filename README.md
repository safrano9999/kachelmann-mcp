# KACHELMANN MCP container

Minimal Alpine-based container for KACHELMANN's authenticated Streamable HTTP
MCP server. The image contains the KACHELMANN Python service layer and connects
directly to the configured MariaDB/MySQL or PostgreSQL database service for all
tools, including document and asset operations. Markdown, uploaded files, and
images use `LONGBLOB` or `BYTEA`; KACHELMANN's SQLite mode uses `BLOB` in the
Fedora main container.

The published image is:

```text
ghcr.io/safrano9999/kachelmann-mcp
```

Each build checks out the current KACHELMANN `main` branch, matching the latest
ZIP/APK source line. The resolved commit is recorded in the image metadata for
traceability without pinning future builds. The runtime endpoint is `/mcp`;
its default port is `8005` and `KACHELMANN_MCP_PORT` overrides it at runtime.

Required runtime settings:

```env
KACHELMANN_DB_BACKEND=postgres
KACHELMANN_DB_URL=postgres
KACHELMANN_DB_PORT=5432
KACHELMANN_DB_NAME=kachelmann
KACHELMANN_DB_USER=kachelmann
KACHELMANN_DB_PW=change-me
KACHELMANN_EDITOR_TOKEN=change-me
KACHELMANN_MCP_ENABLED=true
KACHELMANN_MCP_HOST=0.0.0.0
KACHELMANN_MCP_PORT=8005
KACHELMANN_MCP_ALLOWED_HOSTS=kachelmann-mcp:*
```

The sidecar has no persistent or shared content volume and no WebUI proxy
configuration. Configure the same database service, credentials, database
name, and table prefix as the matching KACHELMANN instance. PostgreSQL stores
document bytes as `BYTEA`, MariaDB/MySQL as `LONGBLOB`, and SQLite as `BLOB`.
SQLite persistence belongs exclusively to KACHELMANN's existing database
volume in the Fedora main container; the volume-free external sidecar is for
the networked database backends.

Use the same value as the MCP Bearer credential:

```sh
export MCP_BEARER_TOKEN="$KACHELMANN_EDITOR_TOKEN"
```

Run `./setup.sh` to create or update an instance below `CONTAINER/<name>`.
The shared setup logic offers TUN, manual publishing, or port ranges 2-5 and
renders both Compose and Quadlet files. The internal bind host/port and the
external publish host/port remain independently configurable.
