# Centralized Image Building
# Build all custom Docker images from a single location

.PHONY: help build-all caddy transmission transmission-exporter vault-tools clean

# Default target
help:
	@echo "Image Building Commands:"
	@echo "  build-all            - Build all custom images"
	@echo "  caddy                - Build Caddy with Cloudflare DNS support"
	@echo "  transmission         - Build Transmission with VPN (Gluetun)"
	@echo "  transmission-exporter - Build ARM64 Transmission Prometheus exporter"
	@echo "  vault-tools          - Build Vault tools image (kubectl, vault-cli, argon2)"
	@echo "  clean                - Remove all built images"

# Build all images
build-all: caddy transmission transmission-exporter vault-tools
	@echo "✅ All images built successfully"

# Build Caddy with Cloudflare DNS plugin
caddy:
	@echo "🔨 Building Caddy with Cloudflare DNS support..."
	@docker build -f caddy/Dockerfile -t caddy:local ../services/caddy
	@echo "✅ Caddy image built: caddy:local"

# Build Transmission with VPN
transmission:
	@echo "🔨 Building Transmission with VPN support..."
	@docker build -f transmission/Dockerfile -t transmission:local ../services/transmission
	@echo "✅ Transmission image built: transmission:local"

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
	@docker rmi caddy:local 2>/dev/null || true
	@docker rmi transmission:local 2>/dev/null || true
	@docker rmi transmission-exporter:local 2>/dev/null || true
	@docker rmi vault-tools:local 2>/dev/null || true
	@echo "✅ Images cleaned up"