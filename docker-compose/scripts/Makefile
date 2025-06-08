# Environment-specific Makefile
# This file is symlinked to environment directories (wroclaw/, kyiv/, etc.)
# It wraps the deploy script with make's convenience and supports service selection

# Auto-detect services in current directory
SERVICES := $(shell find . -maxdepth 1 -name "*.yaml" -not -name "docker-compose.yaml" 2>/dev/null | sed 's|./||; s|.yaml||' | sort)

# Check for selected service (from environment variable or scripts/.service file)
SELECTED_SERVICE := $(if $(SERVICE),$(SERVICE),$(shell test -f ../scripts/.service && cat ../scripts/.service))

# Generate service-specific targets dynamically  
SERVICE_TARGETS := $(foreach service,$(SERVICES),$(addprefix $(service)-,up down restart logs status clean))
AUTHELIA_TARGETS := $(if $(findstring authelia,$(SERVICES)),authelia-get-code authelia-generate-secrets authelia-generate-password authelia-clean-db)
CADDY_TARGETS := $(if $(findstring caddy,$(SERVICES)),caddy-validate)  
MONITORING_TARGETS := $(if $(findstring monitoring,$(SERVICES)),monitoring-backup monitoring-generate-secrets)

.PHONY: help setup up down restart logs status clean select unselect all-setup all-up all-down all-restart all-logs all-status all-clean $(SERVICE_TARGETS) $(AUTHELIA_TARGETS) $(CADDY_TARGETS) $(MONITORING_TARGETS)

# Default target
help: ## Show available commands
	@echo 'Environment Service Management'
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		echo "Currently selected service: $(SELECTED_SERVICE)"; \
	else \
		echo "No service selected"; \
	fi
	@echo ''
	@echo 'Service Selection:'
	@echo '  make select SERVICE=<name>        Select a service to work on'
	@echo '  make unselect                     Clear service selection'
	@echo ''
	@echo 'Selected Service Commands (when service is selected):'
	@echo '  make setup                        Setup selected service only'
	@echo '  make up                           Start selected service'
	@echo '  make down                         Stop selected service'  
	@echo '  make restart                      Restart selected service'
	@echo '  make logs                         Show logs for selected service'
	@echo '  make status                       Show status of selected service'
	@echo '  make clean                        Clean selected service'
	@echo ''
	@echo 'All Services Commands:'
	@echo '  make all-setup                    Setup all services'
	@echo '  make all-up                       Start all services'
	@echo '  make all-down                     Stop all services'  
	@echo '  make all-restart                  Restart all services'
	@echo '  make all-logs                     Show logs for all services'
	@echo '  make all-status                   Show status of all services'
	@echo '  make all-clean                    Clean all services'
	@echo ''
	@echo 'Legacy Commands (still supported):'
	@echo '  make <service>-<action>           Run action on specific service'
	@echo ''
	@if [ -n "$(SERVICES)" ]; then \
		echo 'Available Services: $(SERVICES)'; \
		echo ''; \
		echo 'Service-specific Actions:'; \
		if echo "$(SERVICES)" | grep -q authelia; then \
			echo '  make authelia-get-code            Get verification code'; \
			echo '  make authelia-generate-secrets    Generate new secrets'; \
			echo '  make authelia-generate-password   Generate new password'; \
			echo '  make authelia-clean-db            Remove database'; \
		fi; \
		if echo "$(SERVICES)" | grep -q caddy; then \
			echo '  make caddy-validate               Validate Caddyfile'; \
		fi; \
		if echo "$(SERVICES)" | grep -q monitoring; then \
			echo '  make monitoring-backup            Backup data'; \
			echo '  make monitoring-generate-secrets  Generate new secrets'; \
		fi; \
	else \
		echo 'No services found in current directory'; \
	fi
	@echo ''
	@echo 'Examples:'
	@echo '  make select SERVICE=authelia      Select authelia'
	@echo '  make setup                        Setup authelia (selected service)'
	@echo '  make up                           Start authelia'
	@echo '  make all-up                       Start all services'

# Service selection commands
select: ## Select a service to work on
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ Usage: make select SERVICE=<name>"; \
		echo "Available services: $(SERVICES)" | sed 's/ /, /g'; \
		exit 1; \
	fi
	@if ! echo "$(SERVICES)" | grep -q "$(SERVICE)"; then \
		echo "❌ Service '$(SERVICE)' not found"; \
		echo "Available services: $(SERVICES)" | sed 's/ /, /g'; \
		exit 1; \
	fi
	@echo "$(SERVICE)" > ../scripts/.service
	@echo "✓ Selected service: $(SERVICE)"

unselect: ## Clear service selection
	@rm -f ../scripts/.service
	@echo "✓ Service selection cleared"

# Commands that operate on selected service (if any) or all services
setup: ## Setup selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) setup; \
	else \
		../scripts/deploy setup; \
	fi

up: ## Start selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) up; \
	else \
		../scripts/deploy up; \
	fi

down: ## Stop selected service or all services  
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) down; \
	else \
		../scripts/deploy down; \
	fi

restart: ## Restart selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) restart; \
	else \
		../scripts/deploy restart; \
	fi

logs: ## Show logs for selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) logs; \
	else \
		../scripts/deploy logs; \
	fi

status: ## Show status of selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) status; \
	else \
		../scripts/deploy status; \
	fi

clean: ## Clean selected service or all services
	@if [ -n "$(SELECTED_SERVICE)" ]; then \
		../scripts/deploy $(SELECTED_SERVICE) clean; \
	else \
		../scripts/deploy clean; \
	fi

# All-services commands (always operate on all services)
all-setup: ## Setup all services
	@../scripts/deploy setup

all-up: ## Start all services
	@../scripts/deploy up

all-down: ## Stop all services  
	@../scripts/deploy down

all-restart: ## Restart all services
	@../scripts/deploy restart

all-logs: ## Show logs for all services
	@../scripts/deploy logs

all-status: ## Show status of all services
	@../scripts/deploy status

all-clean: ## Clean all services
	@../scripts/deploy clean

# All service-specific hyphenated commands (service-action pattern)
$(SERVICE_TARGETS) $(AUTHELIA_TARGETS) $(CADDY_TARGETS) $(MONITORING_TARGETS):
	@service=$(word 1,$(subst -, ,$@)); \
	action=$$(echo "$@" | sed "s/^$$service-//"); \
	../scripts/deploy $$service $$action

# Catch unknown targets
%:
	@echo "❌ Unknown command: $@"
	@echo ""
	@echo "💡 Available commands:"
	@echo "   General: setup, up, down, restart, logs, status, clean"
	@if [ -n "$(SERVICES)" ]; then \
		echo "   Service actions: <service>-<action> (e.g., authelia-up, caddy-status)"; \
		echo "   Available services: $(SERVICES)" | sed 's/ /, /g'; \
	fi
	@echo ""
	@echo "Use 'make help' for full command list"
	@exit 1