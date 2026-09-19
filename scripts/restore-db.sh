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
"$ROOT_DIR/scripts/compose.sh" up -d mysql

case "$DUMP_FILE" in
    *.gz)
        # Expanded by the shell inside the MySQL container.
        # shellcheck disable=SC2016
        gzip -dc "$DUMP_FILE" | "$ROOT_DIR/scripts/compose.sh" exec -T mysql sh -ec \
            'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
        ;;
    *)
        # Expanded by the shell inside the MySQL container.
        # shellcheck disable=SC2016
        "$ROOT_DIR/scripts/compose.sh" exec -T mysql sh -ec \
            'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$DUMP_FILE"
        ;;
esac

echo "Database restore completed."
