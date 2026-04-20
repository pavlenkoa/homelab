FROM qmcgaw/gluetun:latest@sha256:f7738494fda6cc909586cd39470379091a3a1035a02a5b5c89c7a4c071ab6269

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
