#!/bin/bash
#--------------------------------------
# Script Name:  entrypoint.sh
# Author:       akombeiz@ukaachen.de, hheidemeyer@ukaachen.de
# Purpose:      Configures the WildFly server for the AKTIN emergency department system.
#--------------------------------------

set -e

DEV_PROPERTIES=/usr/share/aktin/dev-aktin.properties
PROD_PROPERTIES=/etc/aktin/aktin.properties
WILDLFY_PROPERTIES=/opt/wildfly/standalone/configuration/aktin.properties

if [ "$DEV_MODE" = "true" ]; then
  echo "Running in DEV mode"
  ln -sf "${DEV_PROPERTIES}" "${WILDLFY_PROPERTIES}"
else
  echo "Running in PROD mode"
  ln -sf "${PROD_PROPERTIES}" "${WILDLFY_PROPERTIES}"
fi

exec /opt/wildfly/bin/standalone.sh -b 0.0.0.0
