FROM qmcgaw/gluetun:latest@sha256:7c9d3088ef552c66ceea81d6b7650db203556c09774813dca13620473decfe7e

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
