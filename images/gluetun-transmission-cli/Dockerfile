FROM qmcgaw/gluetun:latest@sha256:3e439a7ff285f5782278881675d90ac3b17733e591c68fa7097fa84769ef0e6c

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
