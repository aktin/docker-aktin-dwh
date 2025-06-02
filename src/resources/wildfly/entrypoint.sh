#!/bin/bash

if [ "$DEV_MODE" = "true" ]; then
  ln -sf /etc/aktin/.dev/aktin-dev.properties /opt/wildfly/standalone/configuration/aktin.properties
else
  ln -sf /etc/aktin/aktin.properties /opt/wildfly/standalone/configuration/aktin.properties
fi

exec /opt/wildfly/bin/standalone.sh -b 0.0.0.0
