# --------------------------------------
# WildFly Application Server for i2b2/AKTIN
# Authors: akombeiz@ukaachen.de, shuening@ukaachen.de, skurka@ukaachen.de, hheidemeyer@ukaachen.de
# Purpose: Provides Java application server environment with i2b2 and AKTIN components along with Python and R data processing capabilities for
# the emergency department system Includes German locale support and security configurations
# --------------------------------------

FROM ubuntu:__UBUNTU_VERSION__

ARG BUILD_TIME
ARG WILDFLY_UID=101

LABEL org.opencontainers.image.created=${BUILD_TIME} \
    org.opencontainers.image.authors="akombeiz@ukaachen.de, shuening@ukaachen.de, skurka@ukaachen.de, hheidemeyer@ukaachen.de" \
    org.opencontainers.image.source="https://github.com/aktin/docker-aktin-dwh" \
    org.opencontainers.image.version="__DWH_GITHUB_TAG__" \
    org.opencontainers.image.revision="__WILDFLY_CONTAINER_REVISION__" \
    org.opencontainers.image.vendor="AKTIN" \
    org.opencontainers.image.title="AKTIN Wildfly" \
    org.opencontainers.image.description="Java application server with AKTIN Data Warehouse"

# Default runtime configuration (can be overridden via docker run / compose)
ENV LANG=de_DE.UTF-8 \
    LC_ALL=de_DE.UTF-8 \
    TZ=Europe/Berlin \
    DEV_MODE=false \
    DB_HOST=database \
    DB_PORT=5432

# Configure the timezone non-interactively
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Switch to regional German mirrors
RUN sed -i 's/archive.ubuntu.com/de.archive.ubuntu.com/g' /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true

# Install locales (en_US as fallback) and essential packages
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends locales-all tzdata gosu __UBUNTU_DEPENDENCIES__ wget \
    && rm -rf /var/lib/apt/lists/

# Create stable wildfly user/group with fixed numeric UID/GID.
RUN groupadd --system --gid "${WILDFLY_GID}" wildfly  \
    && useradd --system --uid "${WILDFLY_UID}" --gid "${WILDFLY_GID}" --home-dir /var/lib/wildfly --shell /usr/sbin/nologin wildfly

WORKDIR /opt/wildfly
COPY --chown=${WILDFLY_UID}:${WILDFLY_GID} ./wildfly ./
COPY --chown=${WILDFLY_UID}:${WILDFLY_GID} ./import-scripts/* /var/lib/aktin/import-scripts/
COPY --chown=${WILDFLY_UID}:${WILDFLY_GID} ./aktin.properties /etc/aktin/
COPY --chown=${WILDFLY_UID}:${WILDFLY_GID} ./dev-aktin.properties /usr/share/aktin/
COPY ./entrypoint.sh /entrypoint.sh

# Set permissions and link configuration.
RUN chmod +x /entrypoint.sh \
    && ln -sf /etc/aktin/aktin.properties /opt/wildfly/standalone/configuration/aktin.properties \
    && chown -R "${WILDFLY_UID}:${WILDFLY_GID}" /opt/wildfly /etc/aktin /var/lib/aktin /usr/share/aktin/

EXPOSE 8080

# Switch back to WildFly user for enhanced security
USER wildfly

ENTRYPOINT ["/entrypoint.sh"]
