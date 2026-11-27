#!/bin/bash
set -euo pipefail

socket_gid=$(stat -c '%g' /var/run/docker.sock)
if ! getent group "$socket_gid" > /dev/null; then
    groupadd --gid "$socket_gid" "docker-socket-${socket_gid}"
fi
if [ "$socket_gid" != "0" ]; then
    usermod --append --groups "$socket_gid" meld
fi
export HOME=/home/meld
exec gosu meld "$@"
