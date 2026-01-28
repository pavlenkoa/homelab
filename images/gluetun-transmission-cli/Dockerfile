FROM qmcgaw/gluetun:latest@sha256:1aa28a0db802279d852b08d2358867bd75e2e319431a5da53d3cbb9a6c19fdab

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
