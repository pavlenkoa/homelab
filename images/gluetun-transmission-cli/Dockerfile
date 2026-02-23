FROM qmcgaw/gluetun:latest@sha256:495cdc65ace4c110cf4de3d1f5f90e8a1dd2eb0f8b67151d1ad6101b2a02a476

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
