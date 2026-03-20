FROM ghcr.io/openclaw/openclaw:2026.3.8

# Install media tools for file inspection
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*
USER 1000
