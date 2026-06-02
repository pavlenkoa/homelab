FROM qmcgaw/gluetun:latest@sha256:10b4895fde4499c2d1d9fbd8e681d040ede0efe8c6cfe5d0c51daf0461836ee8

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
