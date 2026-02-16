FROM qmcgaw/gluetun:latest@sha256:a26bf64824e15a841c6ab9757a008969ae814ab3991c22f1f397c7c303575623

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
