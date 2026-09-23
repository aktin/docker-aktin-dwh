#!/bin/bash
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
TEST_DATABASE_MARKER="${PGDATA}/.aktin-test-database"

if [ "${TEST_DATABASE:-false}" != "true" ]; then
    echo "PostgreSQL test database mode disabled"
    exit 0
fi

echo "PostgreSQL test database mode enabled"

gosu postgres /usr/local/bin/ensure-test-database.sh

touch "${TEST_DATABASE_MARKER}"
chown postgres:postgres "${TEST_DATABASE_MARKER}"