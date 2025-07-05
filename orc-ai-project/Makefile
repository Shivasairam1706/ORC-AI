# Makefile for ORC AI Stack with Podman Compose

# Project name used to label Podman Compose resources
PROJECT_NAME=orc-ai-project

# The main compose file
COMPOSE_FILE=podman-compose.yml

# Declare all targets as phony to avoid conflicts with file names
.PHONY: up down restart logs ps build stop clean status shell dags grafana-import

# Start all services in detached mode using Podman Compose
up:
	@echo "[INFO] Starting all services using Podman Compose..."
	podman-compose -f $(COMPOSE_FILE) up -d

# Stop and remove all running services
down:
	@echo "[INFO] Stopping and removing all services..."
	podman-compose -f $(COMPOSE_FILE) down

# Restart the services by running 'down' followed by 'up'
restart: down up

# Build all containers defined in the compose file
build:
	@echo "[INFO] Building containers..."
	podman-compose -f $(COMPOSE_FILE) build

# Display real-time logs from all containers (press Ctrl+C to exit)
logs:
	@echo "[INFO] Displaying logs... (press Ctrl+C to exit)"
	podman-compose -f $(COMPOSE_FILE) logs -f

# List all running containers and their status
ps:
	@echo "[INFO] Listing running containers..."
	podman-compose -f $(COMPOSE_FILE) ps

# Stop all running containers without removing them
stop:
	@echo "[INFO] Stopping all containers..."
	podman-compose -f $(COMPOSE_FILE) stop

# Remove all application data and volumes
clean:
	@echo "[INFO] Removing all volumes and data directories..."
	rm -rf ./orc_ai_data

# Display the health status of each container in the project
status:
	@echo "[INFO] Healthcheck status of all containers:"
	podman ps --filter label=io.podman.compose.project=$(PROJECT_NAME) --format "table {{.Names}}\t{{.Status}}"

# Open a shell session into the Airflow Webserver container
shell:
	@echo "[INFO] Getting a shell into Airflow Webserver..."
	podman exec -it orc-ai-webserver /bin/bash

# List all DAGs currently registered with Airflow
dags:
	@echo "[INFO] Listing all DAGs in Airflow..."
	podman exec -it orc-ai-webserver airflow dags list

# Import Grafana dashboard from JSON file using HTTP POST API
# Requires Grafana to be running and admin credentials to be passed in env
# Uses base64 encoding for the Basic Auth header
# Assumes dashboard JSON is located at the specified path
# Relies on the GRAFANA_ADMIN_PASSWORD environment variable

# Example:
#   make grafana-import GRAFANA_ADMIN_PASSWORD=yourpassword

grafana-import:
	@echo "[INFO] Importing Grafana dashboard..."
	curl -X POST http://localhost:3000/api/dashboards/db \
		-H "Content-Type: application/json" \
		-H "Authorization: Basic $$(echo -n admin:$$GRAFANA_ADMIN_PASSWORD | base64)" \
		--data-binary @./orc_ai_data/grafana/provisioning/dashboards/orc-ai-dashboard.json
