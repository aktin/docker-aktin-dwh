#!/bin/bash
set -euo pipefail

TEST_DATABASE_NAME="${TEST_DATABASE_NAME:-aktin_test}"
MANAGED_BY="docker-aktin-dwh"

if ! psql -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${TEST_DATABASE_NAME}'" \
    | grep -q 1; then
    echo "Test database '${TEST_DATABASE_NAME}' does not exist"
    exit 0
fi

managed_by="$(
    psql -U postgres -d "${TEST_DATABASE_NAME}" -tAc \
        "SELECT managed_by
           FROM public.aktin_test_database_metadata
          LIMIT 1" 2>/dev/null || true
)"

managed_by="$(echo "${managed_by}" | xargs)"

if [ "${managed_by}" != "${MANAGED_BY}" ]; then
    echo "Refusing to remove database '${TEST_DATABASE_NAME}': database is not managed by docker-aktin-dwh"
    exit 1
fi

echo "Removing test database '${TEST_DATABASE_NAME}'..."

psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c \
    "SELECT pg_terminate_backend(pid)
       FROM pg_stat_activity
      WHERE datname='${TEST_DATABASE_NAME}'
        AND pid <> pg_backend_pid();"

dropdb -U postgres "${TEST_DATABASE_NAME}"

echo "Test database '${TEST_DATABASE_NAME}' removed"