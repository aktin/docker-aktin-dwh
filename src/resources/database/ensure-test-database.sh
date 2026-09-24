#!/bin/bash
set -euo pipefail

TEST_DATABASE_NAME="${TEST_DATABASE_NAME:-aktin_test}"
MANAGED_BY="docker-aktin-dwh"
FIXTURE_VERSION="1"

ensure_aktin_test_schema() {
    psql -U postgres -d "${TEST_DATABASE_NAME}" -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA IF NOT EXISTS aktin AUTHORIZATION aktin;
GRANT ALL ON SCHEMA aktin TO aktin;
SQL
}

ensure_i2b2_test_database() {
    if psql -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='i2b2_test'" | grep -qx 1; then

        local managed_by
        managed_by="$(psql -U postgres -d i2b2_test -tAc \
            "SELECT managed_by FROM public.aktin_test_database_metadata LIMIT 1" \
            2>/dev/null || true)"
        managed_by="$(echo "${managed_by}" | xargs)"

        if [ "${managed_by}" != "${MANAGED_BY}" ]; then
            echo "Refusing to use existing i2b2_test: it is not managed by docker-aktin-dwh" >&2
            return 1
        fi

        echo "Test database 'i2b2_test' already exists"
        return 0
    fi

    echo "Creating test database 'i2b2_test'..."
    createdb -U postgres --template=template0 i2b2_test

    if ! psql -U postgres -d i2b2_test -v ON_ERROR_STOP=1 \
        -f /usr/local/share/aktin/i2b2_test_init.sql; then
        dropdb -U postgres i2b2_test
        return 1
    fi

    if ! psql -U postgres -d i2b2_test -v ON_ERROR_STOP=1 -c \
        "CREATE TABLE public.aktin_test_database_metadata (
             managed_by text NOT NULL,
             fixture_version integer NOT NULL
         );
         INSERT INTO public.aktin_test_database_metadata
         VALUES ('${MANAGED_BY}', 1);"; then
        dropdb -U postgres i2b2_test
        return 1
    fi

    echo "Test database 'i2b2_test' created"
}

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

    ensure_aktin_test_schema
    ensure_i2b2_test_database
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
ensure_aktin_test_schema
ensure_i2b2_test_database