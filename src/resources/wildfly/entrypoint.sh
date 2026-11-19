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

configure_timezone() {
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" > /etc/timezone
}

configure_properties() {
  if [ "${DEV_MODE:-false}" = "true" ]; then
    echo "Running in DEV mode"
    sed -i "s|^broker\.keys=.*|broker.keys=${BROKER_API_KEY:?BROKER_API_KEY must be set in DEV_MODE}|" "${DEV_PROPERTIES}"
    ln -sf "${DEV_PROPERTIES}" "${WILDFLY_PROPERTIES}"
  else
    echo "Running in PROD mode"
    ln -sf "${PROD_PROPERTIES}" "${WILDFLY_PROPERTIES}"
  fi
}

# Copy the import scripts of this image into the data volume, so an upgrade replaces them
install_import_scripts() {
  mkdir -p "${AKTIN_DATA_DIR}import-scripts" "${AKTIN_DATA_DIR}cda-debug" /var/tmp/report-temp
  cp "${DEFAULT_AKTIN_SCRIPTS_DIR}"import-scripts/* "${AKTIN_DATA_DIR}import-scripts/"
}

# Repair persisted Docker volumes from older images without static UID/GID
repair_permissions() {
  chown -R "${WILDFLY_USER}:${WILDFLY_GROUP}" "${DEFAULT_WORKDIR}" "${AKTIN_CONFIG_DIR}" "${AKTIN_DATA_DIR}" "${DEFAULT_AKTIN_SCRIPTS_DIR}"
  chown "${WILDFLY_USER}:${WILDFLY_GROUP}" /var/tmp/report-temp
}

if [ "$(id -u)" = "0" ]; then
  configure_timezone
  configure_properties
  install_import_scripts
  repair_permissions
  exec gosu "${WILDFLY_USER}:${WILDFLY_GROUP}" "$@"
fi

configure_properties
install_import_scripts
exec "$@"
