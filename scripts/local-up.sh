#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT_DIR/scripts/validate.sh" local
cd "$ROOT_DIR"
docker compose pull
docker compose up -d --remove-orphans
docker compose ps
