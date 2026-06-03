#!/bin/bash
set -e

PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ -f "$PGDATA/PG_VERSION" ]; then
    for script in /updates/update[0-9]*.sql; do
        [ -f "$script" ] || continue
        echo "Running: $(basename "$script")"
        gosu postgres postgres --single -j i2b2 < "$script"
    done
fi

exec docker-entrypoint.sh "$@"
