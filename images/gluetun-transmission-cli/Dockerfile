FROM qmcgaw/gluetun:latest@sha256:7b1dafa3d25cfd891deae52c7973c499f619f7d8eac52fad84f9aa1e5e6e01ca

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
