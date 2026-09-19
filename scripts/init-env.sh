#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${1:-local}

case "$MODE" in
    local)
        TEMPLATE="$ROOT_DIR/.env.example"
        ;;
    production|prod)
        TEMPLATE="$ROOT_DIR/.env.production.example"
        ;;
    *)
        echo "Usage: $0 [local|production]" >&2
        exit 2
        ;;
esac

TARGET="$ROOT_DIR/.env"
if [ -e "$TARGET" ]; then
    echo "$TARGET already exists; it was not overwritten." >&2
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required to generate secrets." >&2
    exit 1
fi

cp "$TEMPLATE" "$TARGET"

replace_value() {
    key=$1
    value=$2
    temp_file="${TARGET}.tmp"
    awk -v key="$key" -v value="$value" '
        index($0, key "=") == 1 { print key "=" value; next }
        { print }
    ' "$TARGET" > "$temp_file"
    mv "$temp_file" "$TARGET"
}

replace_value MYSQL_PASSWORD "$(openssl rand -hex 24)"
replace_value MYSQL_ROOT_PASSWORD "$(openssl rand -hex 24)"
replace_value REDIS_PASSWORD "$(openssl rand -hex 24)"
chmod 600 "$TARGET" 2>/dev/null || true

if [ "$MODE" = "local" ]; then
    mkdir -p "$ROOT_DIR/www" "$ROOT_DIR/backups"
fi

echo "Created $TARGET for $MODE mode."
if [ "$MODE" != "local" ]; then
    echo "Edit TRAEFIK_HOST_RULE, TRAEFIK_NETWORK and resource limits before deployment."
fi
