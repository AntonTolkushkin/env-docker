#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo ".env is missing. Run scripts/init-env.sh first." >&2
    exit 1
fi

APP_ENV=$(sed -n 's/^APP_ENV=//p' "$ENV_FILE" | tail -n 1 | tr -d '\r' | tr -d "'\"")
case "${APP_ENV:-local}" in
    local)
        set -- \
            --env-file "$ENV_FILE" \
            -f "$ROOT_DIR/docker-compose.yml" \
            -f "$ROOT_DIR/docker-compose.override.yml" \
            "$@"
        ;;
    production|prod)
        set -- \
            --env-file "$ENV_FILE" \
            -f "$ROOT_DIR/docker-compose.yml" \
            -f "$ROOT_DIR/docker-compose.prod.yml" \
            "$@"
        ;;
    *)
        echo "Unsupported APP_ENV in .env: $APP_ENV" >&2
        exit 1
        ;;
esac

cd "$ROOT_DIR"
exec docker compose "$@"
