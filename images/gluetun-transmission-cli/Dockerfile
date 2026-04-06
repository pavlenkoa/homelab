FROM qmcgaw/gluetun:latest@sha256:e4de2b8cfa165553ffca8c5b28f2a3caccacf467244e15780b065e3fe6747080

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
