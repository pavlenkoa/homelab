# Centralized Image Building
# Build all custom Docker images from a single location

.PHONY: help build-all gluetun-transmission-cli transmission-exporter vault-tools clean

# Default target
help:
	@echo "Image Building Commands:"
	@echo "  build-all                 - Build all custom images"
	@echo "  gluetun-transmission-cli  - Build Gluetun with transmission-remote CLI"
	@echo "  transmission-exporter     - Build Transmission Prometheus exporter"
	@echo "  vault-tools               - Build Vault tools image (kubectl, vault-cli, authelia)"
	@echo "  clean                     - Remove all built images"

# Build all images
build-all: gluetun-transmission-cli transmission-exporter vault-tools
	@echo "✅ All images built successfully"

# Build Gluetun with transmission-remote CLI
gluetun-transmission-cli:
	@echo "🔨 Building Gluetun with transmission-remote CLI..."
	@docker build -f gluetun-transmission-cli/Dockerfile -t gluetun-transmission-cli:local gluetun-transmission-cli
	@echo "✅ Image built: gluetun-transmission-cli:local"

# Build Transmission exporter for ARM64
transmission-exporter:
	@echo "🔨 Building Transmission exporter for ARM64..."
	@docker build -f transmission-exporter/Dockerfile -t transmission-exporter:local .
	@echo "✅ Transmission exporter built: transmission-exporter:local"

# Build Vault tools image
vault-tools:
	@echo "🔨 Building Vault tools image (kubectl, vault-cli, argon2)..."
	@docker build -f vault-tools/Dockerfile -t vault-tools:local vault-tools
	@echo "✅ Vault tools image built: vault-tools:local"

# Clean up built images
clean:
	@echo "🧹 Removing built images..."
	@docker rmi gluetun-transmission-cli:local 2>/dev/null || true
	@docker rmi transmission-exporter:local 2>/dev/null || true
	@docker rmi vault-tools:local 2>/dev/null || true
	@echo "✅ Images cleaned up"