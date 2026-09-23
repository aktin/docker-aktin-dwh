#!/bin/bash
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
TEST_DATABASE_MARKER="${PGDATA}/.aktin-test-database"

start_temporary_postgres() {
    gosu postgres pg_ctl \
        -D "$PGDATA" \
        -o "-c listen_addresses=''" \
        -w start
}

stop_temporary_postgres() {
    gosu postgres pg_ctl \
        -D "$PGDATA" \
        -m fast \
        -w stop
}

ensure_existing_test_database() {
    echo "Starting PostgreSQL temporarily to check test database..."

    start_temporary_postgres

    gosu postgres /usr/local/bin/ensure-test-database.sh

    touch "${TEST_DATABASE_MARKER}"
    chown postgres:postgres "${TEST_DATABASE_MARKER}"

    stop_temporary_postgres
}

remove_existing_test_database() {
    echo "Starting PostgreSQL temporarily to remove test database..."

    start_temporary_postgres

    gosu postgres /usr/local/bin/remove-test-database.sh

    rm -f "${TEST_DATABASE_MARKER}"

    stop_temporary_postgres
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

    elif [ -f "${TEST_DATABASE_MARKER}" ]; then
        echo "PostgreSQL test database mode disabled"
        remove_existing_test_database

    else
        echo "PostgreSQL test database mode disabled"
    fi
fi

exec docker-entrypoint.sh "$@"