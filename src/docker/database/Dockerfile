# --------------------------------------
# PostgreSQL Database Container for i2b2/AKTIN
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Purpose:      This container extends the official PostgreSQL image to provide a pre-configured
#               database environment for i2b2 and AKTIN. It includes schema initialization,
#               metadata setup, and required updates for the emergency department system.
# --------------------------------------

FROM postgres:__POSTGRESQL_VERSION__

ARG BUILD_TIME

LABEL org.opencontainers.image.created=${BUILD_TIME} \
    org.opencontainers.image.authors="shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de" \
    org.opencontainers.image.source="https://github.com/aktin/docker-aktin-dwh" \
    org.opencontainers.image.version="__DWH_GITHUB_TAG__" \
    org.opencontainers.image.revision="__DATABASE_CONTAINER_VERSION__" \
    org.opencontainers.image.vendor="AKTIN" \
    org.opencontainers.image.title="AKTIN PostgreSQL" \
    org.opencontainers.image.description="PostgreSQL database with i2b2/AKTIN schema"

WORKDIR /sql.d
COPY ./sql/* ./

# Combine SQL scripts into single initialization file
RUN cat \
    i2b2_init.sql \
    i2b2_db.sql \
    update_wildfly_host.sql \
    addon_i2b2crcdata.concept_dimension.sql \
    addon_i2b2metadata.sql \
    update01_convert_zipcodes_to_str.sql \
    update02_add_missing_p21_dates.sql \
    aktin_init.sql \
    > /docker-entrypoint-initdb.d/init.sql \
    && rm -rf /sql.d/*

WORKDIR /
