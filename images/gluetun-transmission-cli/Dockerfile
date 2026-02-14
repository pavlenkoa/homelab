FROM qmcgaw/gluetun:latest@sha256:ad2b65b131ca4faa4882c91d3672aeb72a0c480f8f33d5854f90d8b683da14e6

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
