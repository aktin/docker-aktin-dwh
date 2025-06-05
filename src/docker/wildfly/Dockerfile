# --------------------------------------
# WildFly Application Server for i2b2/AKTIN
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de, hheidemeyer@ukaachen.de
# Purpose:      Provides Java application server environment with i2b2 and AKTIN components
#               along with Python and R data processing capabilities for the emergency
#               department system. Includes German locale support and security configurations.
# --------------------------------------

FROM ubuntu:__UBUNTU_VERSION__

ARG BUILD_TIME
ARG DEV_MODE=false

LABEL org.opencontainers.image.created=${BUILD_TIME} \
    org.opencontainers.image.authors="shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de" \
    org.opencontainers.image.source="https://github.com/aktin/docker-aktin-dwh" \
    org.opencontainers.image.version="__DWH_GITHUB_TAG__" \
    org.opencontainers.image.revision="__HTTPD_CONTAINER_VERSION__" \
    org.opencontainers.image.vendor="AKTIN" \
    org.opencontainers.image.title="AKTIN Wildfly" \
    org.opencontainers.image.description="Java application server with AKTIN Data Warehouse"

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Set German Locale (required for running the AKTIN DWH)
ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de_DE:en
ENV LC_ALL=de_DE.UTF-8
RUN apt-get update && apt-get install -y locales && \
    locale-gen de_DE.UTF-8 && \
    update-locale LANG=de_DE.UTF-8

# Install essential packages and clean up APT cache
RUN apt-get update && apt-get install -y __UBUNTU_DEPENDENCIES__ wget && rm -rf /var/lib/apt/lists/*

RUN adduser --system --group --disabled-login --home /var/lib/wildfly wildfly

WORKDIR /opt/wildfly
COPY ./wildfly ./
COPY ./import-scripts/* /var/lib/aktin/import-scripts/
COPY ./entrypoint.sh /entrypoint.sh
COPY ./aktin.properties /etc/aktin/
COPY ./dev-aktin.properties /usr/share/aktin/
COPY ./aktin.properties /usr/share/aktin/default-aktin.properties

# Set permissions and link configuration
RUN chmod +x /entrypoint.sh \
 && ln -sf /etc/aktin/aktin.properties /opt/wildfly/standalone/configuration/ \
 && chown -R wildfly:wildfly /opt/wildfly /etc/aktin /var/lib/aktin /usr/share/aktin/

EXPOSE 8080

# Switch back to WildFly user for enhanced security
USER wildfly

ENTRYPOINT ["/entrypoint.sh"]
