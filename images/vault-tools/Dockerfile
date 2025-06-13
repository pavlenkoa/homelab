# Single-stage build for vault-tools image
FROM alpine:3.19

LABEL maintainer="homelab@pavlenko.io"
LABEL description="Vault tools image with kubectl, vault-cli, and authelia for secret management"

# Define tool versions
ENV KUBECTL_VERSION=v1.31.0
ENV VAULT_VERSION=1.19.0
ENV AUTHELIA_VERSION=v4.39.4

# Install runtime dependencies and download tools
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    ca-certificates \
    unzip && \
    \
    # Detect architecture
    ARCH=$(uname -m) && \
    case ${ARCH} in \
        x86_64) BIN_ARCH=amd64 ;; \
        aarch64) BIN_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    \
    # Download kubectl
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${BIN_ARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl && \
    \
    # Download and install Vault CLI
    curl -fsSL -o /tmp/vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${BIN_ARCH}.zip" && \
    cd /tmp && unzip vault.zip && \
    mv vault /usr/local/bin/vault && \
    chmod +x /usr/local/bin/vault && \
    \
    # Download and install Authelia (musl version for Alpine compatibility)
    curl -fsSL -o /tmp/authelia.tar.gz "https://github.com/authelia/authelia/releases/download/${AUTHELIA_VERSION}/authelia-${AUTHELIA_VERSION}-linux-${BIN_ARCH}-musl.tar.gz" && \
    cd /tmp && tar -xzf authelia.tar.gz && \
    find /tmp -name "authelia*" -type f -executable | head -1 | xargs -I {} mv {} /usr/local/bin/authelia && \
    chmod +x /usr/local/bin/authelia && \
    \
    # Verify installations
    kubectl version --client && \
    vault version && \
    /usr/local/bin/authelia --version && \
    \
    # Clean up download artifacts
    rm -rf /tmp/* && \
    apk del unzip

# Create non-root user for security
RUN addgroup -S vault-tools && \
    adduser -S vault-tools -G vault-tools -h /home/vault-tools

# Set working directory
WORKDIR /home/vault-tools

# Switch to non-root user
USER vault-tools

# Default command
CMD ["/bin/bash"]