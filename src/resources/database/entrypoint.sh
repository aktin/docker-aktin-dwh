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

if [ "${TEST_DATABASE:-false}" = "true" ]; then
    echo "PostgreSQL test database mode enabled"
else
    echo "PostgreSQL test database mode disabled"
fi

exec docker-entrypoint.sh "$@"
