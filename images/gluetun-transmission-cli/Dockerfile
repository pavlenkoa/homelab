FROM qmcgaw/gluetun:latest@sha256:eb84287679350bd1360f8c01b09535f779cac1fde43934c2bc37b06eeb9856a7

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
