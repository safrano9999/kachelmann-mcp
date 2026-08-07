#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REGISTRY_IMAGE="ghcr.io/safrano9999/kachelmann-mcp:latest"
LOCAL_IMAGE="${KACHELMANN_MCP_LOCAL_IMAGE:-localhost/kachelmann-mcp:latest}"
DEFAULT_INSTANCE="kachelmann-mcp"

NO_BUILD=false
NO_CACHE=false
IMG_CHOICE=""
INSTANCE="${CONFIG_CONTAINER_NAME:-}"

show_help() {
    cat <<'EOF'
Usage: ./setup.sh [OPTIONS] [INSTANCE]

Options:
  --config-only  Configure and render the instance without an image operation
  --pull         Pull the configured GHCR image
  --build        Build the image from the local KACHELMANN source checkout
  --no-cache     Disable the local image build cache
  --help         Show this help and exit

Generated runtime files are kept below CONTAINER/INSTANCE. New instances use
TUN by default and can instead select manual publishing or port range 2-5.
EOF
}

for argument in "$@"; do
    case "$argument" in
        --help|-h) show_help; exit 0 ;;
        --config-only) NO_BUILD=true ;;
        --pull) IMG_CHOICE=1 ;;
        --build) IMG_CHOICE=2 ;;
        --no-cache) NO_CACHE=true ;;
        --*) echo "Unknown option: $argument" >&2; exit 2 ;;
        *)
            [ -z "$INSTANCE" ] || {
                echo "Only one INSTANCE may be selected" >&2
                exit 2
            }
            INSTANCE="$argument"
            ;;
    esac
done

[ -z "$INSTANCE" ] || [[ "$INSTANCE" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
    echo "Invalid instance name: $INSTANCE" >&2
    exit 2
}

read_value() {
    local file="$1"
    local key="$2"

    [ -f "$file" ] || return 1
    awk -F= -v key="$key" '
        $1 == key {
            print substr($0, index($0, "=") + 1)
            exit
        }
    ' "$file"
}

render_image() {
    local image="$1"
    local compose="$INSTANCE_DIR/$COMPOSE_FILE"
    local quadlet="$INSTANCE_DIR/$QUADLET_FILE"
    local temporary="${compose}.tmp"

    [ -f "$compose" ] && [ -f "$quadlet" ] || {
        echo "config.sh did not render Compose and Quadlet files" >&2
        return 1
    }
    awk '
        /^    build:[[:space:]]*$/ { skipping = 1; next }
        skipping && /^    [^[:space:]]/ { skipping = 0 }
        !skipping { print }
    ' "$compose" > "$temporary"
    mv -f -- "$temporary" "$compose"
    sed -i "s#^    image: .*#    image: $image#" "$compose"
    sed -i "s#^Image=.*#Image=$image#" "$quadlet"
}

finish() {
    python3 "$ROOT/quadlet_finish.py" \
        "$INSTANCE_DIR/$COMPOSE_FILE" \
        "$INSTANCE_DIR/$QUADLET_FILE" \
        "$INSTANCE"
    printf '\n  Instance: %s\n  Compose:  %s\n  Quadlet:  %s\n' \
        "$INSTANCE_DIR" \
        "$INSTANCE_DIR/$COMPOSE_FILE" \
        "$INSTANCE_DIR/$QUADLET_FILE"
}

ensure_ghcr_login() {
    local username

    podman login --get-login ghcr.io >/dev/null 2>&1 && return 0
    command -v gh >/dev/null 2>&1 || {
        echo "gh is required to authenticate to private GHCR images" >&2
        return 1
    }
    username="$(gh api user --jq .login)"
    gh auth token |
        podman login ghcr.io --username "$username" --password-stdin
}

local_source_directory() {
    local candidate

    if [ -n "${KACHELMANN_SOURCE_DIR:-}" ]; then
        candidate="$KACHELMANN_SOURCE_DIR"
        [ -d "$candidate/kachelmann" ] && [ -f "$candidate/requirements.txt" ] || {
            echo "Invalid KACHELMANN_SOURCE_DIR: $candidate" >&2
            return 1
        }
        realpath "$candidate"
        return 0
    fi

    for candidate in "$ROOT/../../KACHELMANN" "$ROOT/../KACHELMANN"; do
        if [ -d "$candidate/kachelmann" ] && [ -f "$candidate/requirements.txt" ]; then
            realpath "$candidate"
            return 0
        fi
    done
    echo "KACHELMANN source checkout not found; set KACHELMANN_SOURCE_DIR" >&2
    return 1
}

build_local_image() {
    local source revision
    local -a arguments=(build --pull=always --tag "$LOCAL_IMAGE")

    source="$(local_source_directory)"
    revision="$(git -C "$source" rev-parse HEAD 2>/dev/null || printf unknown)"
    $NO_CACHE && arguments+=(--no-cache)
    arguments+=(
        --build-arg "KACHELMANN_SOURCE_REVISION=$revision"
        --file "$ROOT/Containerfile"
        "$source"
    )
    podman "${arguments[@]}"
}

instance_arguments=(
    "$ROOT"
    --config "$ROOT/config.sh"
    --default-name "$DEFAULT_INSTANCE"
)
[ -z "$INSTANCE" ] || instance_arguments+=(--name "$INSTANCE")
INSTANCE_DIR="$(python3 "$ROOT/container-instance-setup.py" "${instance_arguments[@]}")"
INSTANCE="${INSTANCE_DIR##*/}"
ENV_FILE="$INSTANCE.env"
BUILD_FILE="${INSTANCE}_build.conf"
COMPOSE_FILE="${INSTANCE}-compose.yml"
QUADLET_FILE="${INSTANCE}.container"

echo "  Configuring instance $INSTANCE..."
(
    cd "$INSTANCE_DIR"
    CONFIG_CONTAINER_NAME="$INSTANCE" \
    CONFIG_CONTAINER_IMAGE="$DEFAULT_REGISTRY_IMAGE" \
        bash ./config.sh
)
[ ! -f "$INSTANCE_DIR/$ENV_FILE" ] || chmod 0600 "$INSTANCE_DIR/$ENV_FILE"

REGISTRY_IMAGE="$(read_value "$INSTANCE_DIR/$BUILD_FILE" KACHELMANN_MCP_IMAGE || true)"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-$DEFAULT_REGISTRY_IMAGE}"
[[ "$REGISTRY_IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9._/@:-]*$ ]] || {
    echo "Invalid KACHELMANN_MCP_IMAGE: $REGISTRY_IMAGE" >&2
    exit 2
}
render_image "$REGISTRY_IMAGE"

if $NO_BUILD; then
    finish
    echo "  Configuration complete; no image operation was requested."
    exit 0
fi

if [ -z "$IMG_CHOICE" ]; then
    printf '\n  Image source:\n    (1) Pull %s\n    (2) Build %s\n' \
        "$REGISTRY_IMAGE" "$LOCAL_IMAGE"
    read -rp "  Choose [1/2] (default: 2): " IMG_CHOICE
    IMG_CHOICE="${IMG_CHOICE:-2}"
fi

case "$IMG_CHOICE" in
    1)
        command -v podman >/dev/null 2>&1 || {
            echo "podman is required to pull the image" >&2
            exit 1
        }
        case "$REGISTRY_IMAGE" in ghcr.io/*) ensure_ghcr_login ;; esac
        podman pull --retry 10 --retry-delay 5s "$REGISTRY_IMAGE"
        render_image "$REGISTRY_IMAGE"
        ;;
    2)
        command -v podman >/dev/null 2>&1 || {
            echo "podman is required to build the image" >&2
            exit 1
        }
        build_local_image
        render_image "$LOCAL_IMAGE"
        ;;
    *)
        echo "Invalid image choice: $IMG_CHOICE" >&2
        exit 2
        ;;
esac

finish
