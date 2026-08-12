# KACHELMANN MCP container

Minimal Alpine-based container for KACHELMANN's authenticated Streamable HTTP
MCP server. The image contains the KACHELMANN Python service layer and connects
directly to the configured MariaDB/MySQL, PostgreSQL, or SQLite database; it
does not proxy through the KACHELMANN WebUI.

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
KACHELMANN_CONTENT_PATH=/var/lib/kachelmann/content
KACHELMANN_CONTENT_GID=10001
KACHELMANN_EDITOR_TOKEN=change-me
KACHELMANN_MCP_ENABLED=true
KACHELMANN_MCP_HOST=0.0.0.0
KACHELMANN_MCP_PORT=8005
KACHELMANN_MCP_ALLOWED_HOSTS=kachelmann-mcp:*
```

The sidecar and its matching Fedora container must mount the same named volume
at `/var/lib/kachelmann:z`. Set `KACHELMANN_CONTENT_VOLUME` to the Fedora
instance's exact volume name; do not derive it from the sidecar name. The
current instance mappings are:

```env
# SSH-1
KACHELMANN_CONTENT_VOLUME=fedora44-ai-ssh-1-kachelmann
KACHELMANN_CONTENT_VOLUMES=${KACHELMANN_CONTENT_VOLUME}:/var/lib/kachelmann:z

# uCore
KACHELMANN_CONTENT_VOLUME=fedora44-ai-safrano9999-ucore-kachelmann
KACHELMANN_CONTENT_VOLUMES=${KACHELMANN_CONTENT_VOLUME}:/var/lib/kachelmann:z
```

Start Fedora once before a new sidecar so its root process can initialize the
shared directory with group 10001 and modes 2770/0660. The sidecar runs as
UID/GID 10001 and then writes through those group permissions.

Use the same value as the MCP Bearer credential:

```sh
export MCP_BEARER_TOKEN="$KACHELMANN_EDITOR_TOKEN"
```

Run `./setup.sh` to create or update an instance below `CONTAINER/<name>`.
The shared setup logic offers TUN, manual publishing, or port ranges 2-5 and
renders both Compose and Quadlet files. The internal bind host/port and the
external publish host/port remain independently configurable.
