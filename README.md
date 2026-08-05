# KACHELMANN MCP container

Minimal Alpine-based container for KACHELMANN's authenticated Streamable HTTP
MCP server. The image contains the KACHELMANN Python service layer and connects
directly to the configured PostgreSQL database; it does not proxy through the
KACHELMANN WebUI.

The published image is:

```text
ghcr.io/safrano9999/kachelmann-mcp
```

The build checks out the immutable KACHELMANN source revision recorded in the
GitHub Actions workflow. The runtime endpoint is `/mcp` on port `11041`.

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
KACHELMANN_MCP_PORT=11041
KACHELMANN_MCP_ALLOWED_HOSTS=kachelmann-mcp:*
```

Use the same value as the MCP Bearer credential:

```sh
export MCP_BEARER_TOKEN="$KACHELMANN_EDITOR_TOKEN"
```
