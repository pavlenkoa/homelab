# Multi-stage build for vault-tools image
FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    wget \
    curl \
    ca-certificates

# Download and install kubectl
ENV KUBECTL_VERSION=v1.31.0
RUN wget -O /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x /tmp/kubectl

# Download and install Vault CLI
ENV VAULT_VERSION=1.19.0
RUN wget -O /tmp/vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" && \
    cd /tmp && unzip vault.zip && \
    chmod +x vault

# Download and install argon2 for password hashing
ENV ARGON2_VERSION=20190702
RUN wget -O /tmp/argon2.tar.gz "https://github.com/P-H-C/phc-winner-argon2/archive/${ARGON2_VERSION}.tar.gz" && \
    cd /tmp && tar -xzf argon2.tar.gz

# Final stage - create minimal runtime image
FROM alpine:3.19

LABEL maintainer="homelab@pavlenko.io"
LABEL description="Vault tools image with kubectl, vault-cli, and argon2 for secret management"

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    ca-certificates \
    make \
    gcc \
    musl-dev

# Install argon2 from source (for password hashing)
COPY --from=builder /tmp/phc-winner-argon2-20190702 /tmp/argon2-src
RUN cd /tmp/argon2-src && \
    make && \
    make install PREFIX=/usr && \
    cd / && rm -rf /tmp/argon2-src

# Copy pre-built tools from builder stage
COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
COPY --from=builder /tmp/vault /usr/local/bin/vault

# Create non-root user for security
RUN addgroup -S vault-tools && \
    adduser -S vault-tools -G vault-tools -h /home/vault-tools

# Set working directory
WORKDIR /home/vault-tools

# Switch to non-root user
USER vault-tools

# Verify installations
RUN kubectl version --client && \
    vault version && \
    (argon2 -h || true) | head -1

# Default command
CMD ["/bin/bash"]