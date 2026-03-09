FROM qmcgaw/gluetun:latest@sha256:57b59e8191b8aee00b81a5c20d2541bb1a050fda153c0f116462cf5a783605bb

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
