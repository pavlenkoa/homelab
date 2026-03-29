FROM qmcgaw/gluetun:latest@sha256:9b91146e09bfe20193860ecf7b25a45e14f0c6a0b9822c83fe3d62f2d9d52f4f

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
