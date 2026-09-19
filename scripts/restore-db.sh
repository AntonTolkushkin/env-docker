#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
ASSUME_YES=0

if [ "${1:-}" = "--yes" ]; then
    ASSUME_YES=1
    shift
fi

DUMP_FILE=${1:-}
if [ -z "$DUMP_FILE" ] || [ ! -f "$DUMP_FILE" ]; then
    echo "Usage: $0 [--yes] /path/to/dump.sql[.gz]" >&2
    exit 2
fi

if [ ! -f "$ROOT_DIR/.env" ]; then
    echo ".env is missing." >&2
    exit 1
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    printf 'This will overwrite data in the configured Bitrix database. Continue? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 1 ;;
    esac
fi

cd "$ROOT_DIR"
docker compose up -d mysql

case "$DUMP_FILE" in
    *.gz)
        gzip -dc "$DUMP_FILE" | docker compose exec -T mysql sh -ec \
            'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
        ;;
    *)
        docker compose exec -T mysql sh -ec \
            'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$DUMP_FILE"
        ;;
esac

echo "Database restore completed."
