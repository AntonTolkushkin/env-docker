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

configured_mode=$(sed -n 's/^APP_ENV=//p' "$ENV_FILE" | tail -n 1 | tr -d '\r' | tr -d "'\"")

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed or is not available in PATH." >&2
    exit 1
fi

cd "$ROOT_DIR"

case "$MODE" in
    local)
        if [ "${configured_mode:-local}" != "local" ]; then
            echo "APP_ENV must be local for a local deployment." >&2
            exit 1
        fi
        if [ ! -r "$ROOT_DIR/confs/nginx/certs/finntrail.local/fullchain.pem" ] || \
           [ ! -r "$ROOT_DIR/confs/nginx/certs/finntrail.local/privkey.pem" ]; then
            echo "Local TLS certificate is missing. Run scripts/setup-local-cert.sh." >&2
            exit 1
        fi
        if [ ! -d "$ROOT_DIR/www/public_html" ]; then
            echo "Local document root is missing: $ROOT_DIR/www/public_html" >&2
            exit 1
        fi
        "$ROOT_DIR/scripts/compose.sh" config --quiet
        ;;
    production|prod)
        if [ "$configured_mode" != "production" ] && [ "$configured_mode" != "prod" ]; then
            echo "APP_ENV must be production for a production deployment." >&2
            exit 1
        fi
        if grep -q 'example\.com' "$ENV_FILE"; then
            echo "Set the real TRAEFIK_HOST_RULE in .env before production deployment." >&2
            exit 1
        fi
        "$ROOT_DIR/scripts/compose.sh" config --quiet
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
