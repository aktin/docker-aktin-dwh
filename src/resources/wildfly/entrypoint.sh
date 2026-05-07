#!/bin/bash
#--------------------------------------
# Script Name:  entrypoint.sh
# Author:       akombeiz@ukaachen.de, hheidemeyer@ukaachen.de
# Purpose:      Configures which aktin.properties to use for the AKTIN Data Warehouse
#               and repairs mounted Docker volume permissions before starting WildFly
#--------------------------------------

set -euo pipefail

WILDFLY_USER="wildfly"
WILDFLY_GROUP="wildfly"

DEV_PROPERTIES="/usr/share/aktin/dev-aktin.properties"
PROD_PROPERTIES="/etc/aktin/aktin.properties"
WILDFLY_PROPERTIES="/opt/wildfly/standalone/configuration/aktin.properties"

DEFAULT_WORKDIR="/opt/wildfly/"
AKTIN_CONFIG_DIR="/etc/aktin/"
AKTIN_DATA_DIR="/var/lib/aktin/"
DEFAULT_AKTIN_SCRIPTS_DIR="/usr/share/aktin/"

configure_properties() {
  if [ "${DEV_MODE:-false}" = "true" ]; then
    echo "Running in DEV mode"
    ln -sf "${DEV_PROPERTIES}" "${WILDFLY_PROPERTIES}"
  else
    echo "Running in PROD mode"
    ln -sf "${PROD_PROPERTIES}" "${WILDFLY_PROPERTIES}"
  fi
}

# Repair persisted Docker volumes from older images without static UID/GID
repair_permissions() {
  chown -R "${WILDFLY_USER}:${WILDFLY_GROUP}" "${DEFAULT_WORKDIR}" "${AKTIN_CONFIG_DIR}" "${AKTIN_DATA_DIR}" "${DEFAULT_AKTIN_SCRIPTS_DIR}"
}

if [ "$(id -u)" = "0" ]; then
  repair_permissions
  configure_properties
  exec gosu "${WILDFLY_USER}:${WILDFLY_GROUP}" "$@"
fi

configure_properties
exec "$@"
