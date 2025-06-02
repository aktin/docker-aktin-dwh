#!/bin/bash
CONFIG_FILE=/etc/aktin/aktin.properties
DEFAULT_FILE=/opt/default-aktin.properties

# Copy default only if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No aktin.properties found, copying default configuration..."
    cp "$DEFAULT_FILE" "$CONFIG_FILE"
fi

# Start the application
exec /opt/wildfly/bin/standalone.sh -b 0.0.0.0
