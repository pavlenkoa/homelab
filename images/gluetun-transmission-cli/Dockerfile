FROM qmcgaw/gluetun:latest@sha256:988d9cb1982f688ce51f3511057b90c5c8d01889db60a4d56e5230aebf1d3339

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
