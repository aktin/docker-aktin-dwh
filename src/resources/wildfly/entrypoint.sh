#!/bin/bash
CONFIG_FILE=/etc/aktin/aktin.properties
# Default config file, used to recover missing aktin.properties
DEFAULT_FILE=/usr/share/aktin/default-aktin.properties

# Copy default only if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No aktin.properties found, copying default configuration..."
    cp "$DEFAULT_FILE" "$CONFIG_FILE"
    ln -sf "$CONFIG_FILE" /opt/wildfly/standalone/configuration/aktin.properties
fi

# Start the application
exec /opt/wildfly/bin/standalone.sh -b 0.0.0.0
