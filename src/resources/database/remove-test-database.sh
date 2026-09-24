#!/bin/bash
set -euo pipefail

MANAGED_BY="docker-aktin-dwh"
existing=()

for db in i2b2_test aktin_test; do
    exists="$(psql -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${db}'")"

    [ "${exists}" = "1" ] || continue

    managed_by="$(psql -U postgres -d "${db}" -tAc \
        "SELECT managed_by FROM public.aktin_test_database_metadata LIMIT 1" \
        2>/dev/null || true)"
    managed_by="$(echo "${managed_by}" | xargs)"

    if [ "${managed_by}" != "${MANAGED_BY}" ]; then
        echo "Refusing to remove '${db}': database is not managed by docker-aktin-dwh" >&2
        exit 1
    fi

    existing+=("${db}")
done

for db in "${existing[@]}"; do
    echo "Removing test database '${db}'..."

    psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c \
        "SELECT pg_terminate_backend(pid)
           FROM pg_stat_activity
          WHERE datname='${db}'
            AND pid <> pg_backend_pid();"

    dropdb -U postgres "${db}"
    echo "Test database '${db}' removed"
done