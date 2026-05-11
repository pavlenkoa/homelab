FROM qmcgaw/gluetun:latest@sha256:18a0abe7a020acdf9f80db45440d18487239abde5495a357ceb36517f7ea67cf

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
