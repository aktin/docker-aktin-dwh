#!/bin/bash
set -euo pipefail

if [ "${TEST_DATABASE:-false}" != "true" ]; then
    echo "PostgreSQL test database mode disabled"
    exit 0
fi

echo "PostgreSQL test database mode enabled"

gosu postgres /usr/local/bin/ensure-test-database.sh