FROM qmcgaw/gluetun:latest@sha256:e3272b29a4bc177b389fbdcb54cf9716ccbfc30f04d8b7a35b0a5be9cdb58461

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
