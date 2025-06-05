#!/bin/bash
#--------------------------------------
# Script Name:  entrypoint.sh
# Author:       akombeiz@ukaachen.de, hheidemeyer@ukaachen.de
# Purpose:      Selects and restores configuration file for the AKTIN emergency department system.
#--------------------------------------

set -e

PROD_PROPERTIES=/etc/aktin/aktin.properties
DEV_PROPERTIES=/usr/share/aktin/dev-aktin.properties
DEFAULT_PROPERTIES=/usr/share/aktin/default-aktin.properties
WILDLFY_PROPERTIES=/opt/wildfly/standalone/configuration/aktin.properties

if [ "$DEV_MODE" = "true" ]; then
  echo "Running in DEV mode"
  ln -sf "${DEV_PROPERTIES}" "${WILDLFY_PROPERTIES}"
else
  echo "Running in PROD mode"
  # Copy default only if missing
  if [ ! -f "${PROD_PROPERTIES}" ]; then
      echo "No aktin.properties found, copying default configuration..."
      cp "${DEFAULT_PROPERTIES}" "${PROD_PROPERTIES}"
  fi
  ln -sf "${PROD_PROPERTIES}" "${WILDLFY_PROPERTIES}"
fi

exec /opt/wildfly/bin/standalone.sh -b 0.0.0.0
