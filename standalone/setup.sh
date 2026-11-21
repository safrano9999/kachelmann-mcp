#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd "$(dirname "$0")/.." && pwd)
instance=${1:-kachelmann}
if [[ ! "$instance" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "Invalid container name: $instance" >&2
    exit 2
fi
if (( $# )); then shift; fi
directory="$root/CONTAINER/$instance"
mkdir -p "$directory"
for template in config.conf_example container.example env.example; do
    install -m 600 "$root/standalone/$template" "$directory/$template"
done
install -m 700 "$root/config.sh" "$directory/config.sh"
cd "$directory"
export CONFIG_CONTAINER_NAME="$instance"
export CONFIG_CONTAINER_IMAGE=ghcr.io/safrano9999/kachelmann:latest
exec ./config.sh "$@"
