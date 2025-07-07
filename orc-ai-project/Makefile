# Makefile for ORC AI Stack with Podman Compose

# Load environment variables from .env file
include .env
export

# Set default project name and compose file if not provided
PROJECT_NAME ?= orc-ai-project
COMPOSE_FILE ?= podman-compose.yml

# Declare all targets as phony to avoid conflicts with real filenames
.PHONY: up down restart logs ps build stop start clean status shell dags grafana-import help

# Default target that shows available commands
help:
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# Check if podman-compose is installed
check-podman-compose:
	@command -v podman-compose >/dev/null 2>&1 || { echo >&2 "podman-compose not found. Please install it."; exit 1; }

# Start all services in detached mode using Podman Compose
up: check-podman-compose ## Start all services in detached mode
	@echo "[INFO] Starting all services using Podman Compose..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) up -d

# Stop and remove all services
down: check-podman-compose ## Stop and remove all services
	@echo "[INFO] Stopping and removing all services..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) down

# Restart services by calling down and up in sequence
restart: ## Restart all services
	@$(MAKE) down
	@$(MAKE) up

# Build container images defined in the compose file
build: check-podman-compose ## Build all containers
	@echo "[INFO] Building containers..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) build

# Show logs from running containers, follow for real-time
logs: check-podman-compose ## Show container logs
	@echo "[INFO] Displaying logs... (press Ctrl+C to exit)"
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) logs -f

# List all running containers and their details
ps: check-podman-compose ## List running containers
	@echo "[INFO] Listing running containers..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) ps

# Stop running containers without removing them
stop: check-podman-compose ## Stop containers without removing them
	@echo "[INFO] Stopping all containers..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) stop

# Start/resume stopped containers without recreating them
start: check-podman-compose ## Start/resume stopped containers
	@echo "[INFO] Starting/resuming stopped containers..."
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) podman-compose -f $(COMPOSE_FILE) start

# Clean up only unnecessary files (logs, temp files, etc.), not all data
clean: ## Delete logs, temp, and cache files only
	@echo "[INFO] Cleaning up logs, temp files, and unused data..."
	# Remove specific file types under orc_ai_data
	find ./orc_ai_data -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.pid" -o -name "*.db" \) -exec rm -f {} + 2>/dev/null || true
	# Remove Python bytecode cache folders
	find ./orc_ai_data -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "[INFO] Clean-up completed."

# Display the health check status of containers in the project
status: ## Show health status of containers
	@echo "[INFO] Healthcheck status of all containers:"
	@echo $$(date +"%m/%d/%Y %H:%M:%S:%6N")
	@podman ps --filter label=io.podman.compose.project=$(PROJECT_NAME) --format "table {{.Names}}\t{{.Status}}"

# Open interactive shell into the Airflow Webserver container
shell: ## Open shell into the Airflow Webserver
	@echo "[INFO] Getting a shell into Airflow Webserver..."
	# Find container by name and label, then exec into it
	@podman exec -it $$(podman ps --filter name=webserver --filter label=io.podman.compose.project=$(PROJECT_NAME) --format "{{.ID}}") /bin/bash

# Run Airflow command to list all registered DAGs
dags: ## List Airflow DAGs
	@echo "[INFO] Listing all DAGs in Airflow..."
	@podman exec -it $$(podman ps --filter name=webserver --filter label=io.podman.compose.project=$(PROJECT_NAME) --format "{{.ID}}") airflow dags list

# Import a Grafana dashboard via HTTP API
# Requires GRAFANA_ADMIN_PASSWORD to be defined in the .env file
grafana-import: ## Import Grafana dashboard
	# Exit early if the required password is not set
	@if [ -z "$(GRAFANA_ADMIN_PASSWORD)" ]; then \
	  echo "[ERROR] GRAFANA_ADMIN_PASSWORD is not set. Please define it in the .env file."; exit 1; \
	fi
	@echo "[INFO] Importing Grafana dashboard..."
	# Send POST request to Grafana API with Basic Auth and dashboard JSON payload
	@curl -s -X POST http://localhost:3000/api/dashboards/db \
		-H "Content-Type: application/json" \
		-H "Authorization: Basic $$(echo -n admin:$(GRAFANA_ADMIN_PASSWORD) | base64)" \
		--data-binary "@./orc_ai_data/grafana/provisioning/dashboards/orc-ai-dashboard.json"
