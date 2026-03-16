FROM qmcgaw/gluetun:latest@sha256:73cbc52cfc260955c0898512ffbb4d64437c3cdf7886e643e3d3679b3fcb0e3b

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
