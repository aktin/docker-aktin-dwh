#!/bin/bash
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"

ensure_existing_test_database() {
    echo "Starting PostgreSQL temporarily to check test database..."

    gosu postgres pg_ctl \
        -D "$PGDATA" \
        -o "-c listen_addresses=''" \
        -w start

    gosu postgres /usr/local/bin/ensure-test-database.sh

    gosu postgres pg_ctl \
        -D "$PGDATA" \
        -m fast \
        -w stop
}

if [ -f "$PGDATA/PG_VERSION" ]; then
    for script in /updates/update[0-9]*.sql; do
        [ -f "$script" ] || continue
        echo "Running: $(basename "$script")"
        gosu postgres postgres --single -j i2b2 < "$script"
    done

    if [ "${TEST_DATABASE:-false}" = "true" ]; then
        echo "PostgreSQL test database mode enabled"
        ensure_existing_test_database
    else
        echo "PostgreSQL test database mode disabled"
    fi
fi

exec docker-entrypoint.sh "$@"