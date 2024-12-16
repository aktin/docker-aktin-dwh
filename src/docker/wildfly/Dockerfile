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
LABEL org.opencontainers.image.title="AKTIN Web Interface"
LABEL org.opencontainers.image.description="Apache/PHP web server with i2b2 interface and AKTIN integration"
LABEL org.opencontainers.image.authors="shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de"
LABEL org.opencontainers.image.version="__DWH_DEBIAN_RELEASE__"
LABEL org.opencontainers.image.vendor="AKTIN"

# Prevent interactive prompts during installation
# Set the German locale for the system
ENV DEBIAN_FRONTEND=noninteractive \
   LANG=de_DE.UTF-8 \
   LANGUAGE=de_DE:de \
   LC_ALL=de_DE.UTF-8

# Install essential packages and clean up APT cache
RUN apt-get update && apt-get install -y __UBUNTU_DEPENDENCIES__ \
   && rm -rf /var/lib/apt/lists/* \
   && locale-gen de_DE.UTF-8

# Setup WildFly user and environment
RUN adduser --system --group --disabled-login --home /var/lib/wildfly wildfly

# Copy WildFly distribution
WORKDIR /opt/wildfly
COPY ./wildfly/* ./
COPY ./import-scripts/* /var/lib/aktin/import-scripts/
COPY ./aktin.properties /etc/aktin/

# Install AKTIN datasource
# Remove WildFly configuration history to reduce image size
# Enable Wildfly to read aktin.properties
# Change ownership of WildFly directories to 'wildfly' user
RUN /opt/wildfly/bin/jboss-cli.sh --file=/opt/wildfly/bin/add-aktin-config.cli \
   && rm -rf ./standalone/configuration/standalone_xml_history/current/* \
   && ln -sf /etc/aktin/aktin.properties ./standalone/configuration/ \
   && chown -R wildfly:wildfly /opt/wildfly /etc/aktin /var/lib/aktin

EXPOSE 8080 9990

# Switch back to WildFly user for enhanced security
USER wildfly

CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
