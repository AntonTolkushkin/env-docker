#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT_DIR/scripts/validate.sh" production
"$ROOT_DIR/scripts/compose.sh" pull
"$ROOT_DIR/scripts/compose.sh" run --rm --no-deps php php-fpm -t
"$ROOT_DIR/scripts/compose.sh" run --rm --no-deps nginx nginx -t
"$ROOT_DIR/scripts/compose.sh" up -d --remove-orphans
"$ROOT_DIR/scripts/compose.sh" ps
