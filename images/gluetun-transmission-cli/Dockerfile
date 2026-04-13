FROM qmcgaw/gluetun:latest@sha256:4f1ecfedd717bca7b2d94b405380a717bcf40ba723d82a69428d816744664542

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
