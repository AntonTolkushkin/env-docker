#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${1:-local}
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo ".env is missing. Run scripts/init-env.sh $MODE first." >&2
    exit 1
fi

if grep -q 'CHANGE_ME_' "$ENV_FILE"; then
    echo ".env still contains placeholder secrets." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed or is not available in PATH." >&2
    exit 1
fi

cd "$ROOT_DIR"

case "$MODE" in
    local)
        docker compose config --quiet
        ;;
    production|prod)
        if grep -q 'example\.com' "$ENV_FILE"; then
            echo "Set the real TRAEFIK_HOST_RULE in .env before production deployment." >&2
            exit 1
        fi
        docker compose -f docker-compose.yml -f docker-compose.prod.yml config --quiet
        traefik_network=$(sed -n 's/^TRAEFIK_NETWORK=//p' "$ENV_FILE" | tail -n 1)
        if [ -z "$traefik_network" ]; then
            echo "TRAEFIK_NETWORK is empty." >&2
            exit 1
        fi
        if ! docker network inspect "$traefik_network" >/dev/null 2>&1; then
            echo "External Traefik network '$traefik_network' does not exist." >&2
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [local|production]" >&2
        exit 2
        ;;
esac

echo "Configuration for $MODE mode is valid."
