#!/bin/bash
set -e

if [ "${DEV_MODE:-false}" = "true" ]; then
    export PGDATA=/var/lib/postgresql/test-data
    echo "PostgreSQL test mode: using separate cluster in ${PGDATA}"
fi

PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ -f "$PGDATA/PG_VERSION" ] && [ -s /updates/updates.sql ]; then
    echo "Running: updates.sql"
    gosu postgres postgres --single -j i2b2 < /updates/updates.sql
fi

exec docker-entrypoint.sh "$@"
