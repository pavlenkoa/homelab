FROM qmcgaw/gluetun:latest@sha256:46407f10497e6b09770e63006439053ab88db9b94f009e88bcaef168233d5973

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
