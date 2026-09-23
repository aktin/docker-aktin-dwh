#!/bin/bash
set -euo pipefail

TEST_DATABASE_NAME="${TEST_DATABASE_NAME:-aktin_test}"
MANAGED_BY="docker-aktin-dwh"
FIXTURE_VERSION="1"

if psql -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${TEST_DATABASE_NAME}'" \
    | grep -q 1; then

    managed_by="$(
        psql -U postgres -d "${TEST_DATABASE_NAME}" -tAc \
            "SELECT managed_by
               FROM public.aktin_test_database_metadata
              LIMIT 1" 2>/dev/null || true
    )"

    managed_by="$(echo "${managed_by}" | xargs)"

    if [ "${managed_by}" != "${MANAGED_BY}" ]; then
        echo "Database '${TEST_DATABASE_NAME}' exists but is not managed by docker-aktin-dwh" >&2
        exit 1
    fi

    echo "Test database '${TEST_DATABASE_NAME}' already exists"
    exit 0
fi

echo "Creating test database '${TEST_DATABASE_NAME}'..."

createdb \
    -U postgres \
    --template=template0 \
    "${TEST_DATABASE_NAME}"

psql \
    -U postgres \
    -d "${TEST_DATABASE_NAME}" \
    -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE public.aktin_test_database_metadata (
    managed_by text NOT NULL,
    fixture_version integer NOT NULL
);

INSERT INTO public.aktin_test_database_metadata (
    managed_by,
    fixture_version
)
VALUES (
    '${MANAGED_BY}',
    ${FIXTURE_VERSION}
);
SQL

echo "Test database '${TEST_DATABASE_NAME}' created"