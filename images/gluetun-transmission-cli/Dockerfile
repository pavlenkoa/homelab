FROM qmcgaw/gluetun:latest@sha256:bd84f4f090ca61170c8329a72d4f451255b01f6489486a621bfcb89749fb80ab

# Switch to root to install packages
USER root

# Update package list and install transmission-remote for port forwarding
RUN apk update && \
    apk add --no-cache transmission-remote && \
    rm -rf /var/cache/apk/*

# Gluetun needs to run as root for iptables
