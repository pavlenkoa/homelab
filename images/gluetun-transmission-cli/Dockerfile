FROM qmcgaw/gluetun:latest@sha256:5665416a97ad2823dda6986a581b8913cc3af1b196ac768f5130abad4b0d4f62

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
