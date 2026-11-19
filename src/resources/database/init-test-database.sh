#!/bin/bash
set -euo pipefail

# Loads test patients only into the separate test cluster, never into the production volume
if [ "${DEV_MODE:-false}" != "true" ]; then
    echo "DEV_MODE not set, skipping i2b2 test fixture"
    exit 0
fi

echo "Loading test patients into i2b2..."
psql -v ON_ERROR_STOP=1 -U postgres -d i2b2 -f /usr/local/share/aktin/i2b2_test_fixture.sql
