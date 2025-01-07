# --------------------------------------
# WildFly Application Server for i2b2/AKTIN
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         16 Dec 24
# Purpose:      Provides Java application server environment with i2b2 and AKTIN components
#               along with Python and R data processing capabilities for the emergency
#               department system. Includes German locale support and security configurations.
# --------------------------------------

FROM ubuntu:__UBUNTU_VERSION__

# Build-time metadata
LABEL org.opencontainers.image.title="AKTIN Wildfly"
LABEL org.opencontainers.image.description="Java application server with AKTIN Data Warehouse"
LABEL org.opencontainers.image.authors="shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de"
LABEL org.opencontainers.image.version="__DWH_GITHUB_TAG__-docker__WILDFLY_CONTAINER_VERSION__"
LABEL org.opencontainers.image.vendor="AKTIN"

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
RUN apt-get update && apt-get install -y __UBUNTU_DEPENDENCIES__ && rm -rf /var/lib/apt/lists/*

# Setup WildFly user and environment
RUN adduser --system --group --disabled-login --home /var/lib/wildfly wildfly

# Copy WildFly distribution
WORKDIR /opt/wildfly
COPY ./wildfly ./
COPY ./import-scripts/* /var/lib/aktin/import-scripts/
COPY ./aktin.properties /etc/aktin/

# Enable Wildfly to read aktin.properties
# Change ownership of WildFly directories to 'wildfly' user
RUN ln -sf /etc/aktin/aktin.properties ./standalone/configuration/ \
   && chown -R wildfly:wildfly /opt/wildfly /etc/aktin /var/lib/aktin

EXPOSE 8080 9990

# Switch back to WildFly user for enhanced security
USER wildfly

CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
