# Homelab Root Makefile
# Handles global dependencies

.PHONY: check-deps setup-deps help

# Default target
help:
	@echo "Homelab Dependencies:"
	@echo "  setup-deps    - Setup Python virtual environment and install dependencies"
	@echo "  check-deps    - Check if dependencies are installed"

# Check if dependencies are installed
check-deps:
	@if [ ! -d ".venv" ]; then \
		echo "❌ Virtual environment not found. Run: make setup-deps"; \
		exit 1; \
	fi
	@. .venv/bin/activate && python -c "import jinja2" 2>/dev/null || \
		(echo "❌ jinja2 not installed in venv. Run: make setup-deps" && exit 1)
	@echo "✅ Dependencies ready"

# Setup virtual environment and install dependencies
setup-deps:
	@echo "Setting up Python virtual environment..."
	@if [ ! -d ".venv" ]; then \
		python3 -m venv .venv; \
		echo "✓ Created virtual environment"; \
	else \
		echo "✓ Virtual environment already exists"; \
	fi
	@. .venv/bin/activate && pip install -r scripts/requirements.txt
	@echo "✅ Dependencies installed"