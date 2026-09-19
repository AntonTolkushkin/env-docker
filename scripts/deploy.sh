#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT_DIR/scripts/validate.sh" production
cd "$ROOT_DIR"

docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
