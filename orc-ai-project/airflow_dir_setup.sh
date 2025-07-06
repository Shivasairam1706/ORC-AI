#!/bin/bash

# Create the directory structure on the host
mkdir -p ./orc_ai_data/airflow/logs/dag_processor
mkdir -p ./orc_ai_data/airflow/logs/scheduler
mkdir -p ./orc_ai_data/airflow/logs/triggerer
mkdir -p ./orc_ai_data/airflow/logs/dag_processor_manager
mkdir -p ./orc_ai_data/airflow/dags
mkdir -p ./orc_ai_data/airflow/plugins

# Get the AIRFLOW_UID from .env file or use default
AIRFLOW_UID=${AIRFLOW_UID:-1000}

# Set proper ownership (this might require sudo depending on your setup)
sudo chown -R ${AIRFLOW_UID}:${AIRFLOW_UID} ./orc_ai_data/airflow/

# Set proper permissions
sudo chmod -R 755 ./orc_ai_data/airflow/

echo "Directory structure created and permissions set for AIRFLOW_UID=${AIRFLOW_UID}"