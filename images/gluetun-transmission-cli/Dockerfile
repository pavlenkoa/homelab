FROM qmcgaw/gluetun:latest@sha256:ad6b604e0cecc917a5cb6a8de55cd167ba415da8b7ec13456abb871a84be3c30

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
