#!/bin/bash
set -euo pipefail

TEST_DATABASE_NAME="${TEST_DATABASE_NAME:-aktin_test}"

if psql -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${TEST_DATABASE_NAME}'" \
    | grep -q 1; then

    echo "Test database '${TEST_DATABASE_NAME}' already exists"
    exit 0
fi

echo "Creating test database '${TEST_DATABASE_NAME}'..."

createdb \
    -U postgres \
    --template=template0 \
    "${TEST_DATABASE_NAME}"

echo "Test database '${TEST_DATABASE_NAME}' created"