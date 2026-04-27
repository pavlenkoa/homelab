FROM qmcgaw/gluetun:latest@sha256:725d3e51091dde4ca43e3e3f26e2e6d3d0ccc66821e92d505c3da04958f7d472

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
