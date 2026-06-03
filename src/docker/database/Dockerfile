# --------------------------------------
# PostgreSQL Database Container for i2b2/AKTIN
# Authors: akombeiz@ukaachen.de, shuening@ukaachen.de, skurka@ukaachen.de
# Purpose: This container extends the official PostgreSQL image to provide a pre-configured database environment for i2b2 and AKTIN.
# It includes schema initialization, metadata setup, and required updates for the emergency department system.
# --------------------------------------

FROM postgres:__POSTGRESQL_VERSION__

ARG BUILD_TIME

LABEL org.opencontainers.image.created=${BUILD_TIME} \
    org.opencontainers.image.authors="akombeiz@ukaachen.de, shuening@ukaachen.de, skurka@ukaachen.de" \
    org.opencontainers.image.source="https://github.com/aktin/docker-aktin-dwh" \
    org.opencontainers.image.version="__DWH_GITHUB_TAG__" \
    org.opencontainers.image.revision="__DATABASE_CONTAINER_REVISION__" \
    org.opencontainers.image.vendor="AKTIN" \
    org.opencontainers.image.title="AKTIN PostgreSQL" \
    org.opencontainers.image.description="PostgreSQL database with i2b2/AKTIN schema"

COPY ./sql/init.sql /docker-entrypoint-initdb.d/init.sql
COPY ./sql/update[0-9]*.sql /updates/
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
