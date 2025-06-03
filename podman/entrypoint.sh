#!/bin/bash

# ORC AI Prototype Entrypoint Script

set -e

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service_name to be ready..."

    while ! nc -z "$host" "$port" >/dev/null 2>&1; do
        if [ $attempt -eq $max_attempts ]; then
            echo "ERROR: $service_name is not available after $max_attempts attempts"
            exit 1
        fi
        echo "Attempt $attempt/$max_attempts: $service_name is not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "$service_name is ready!"
}

# Initialize Airflow database if needed
initialize_airflow_db() {
    echo "Initializing Airflow database..."
    airflow db init

    # Create default admin user if it doesn't exist
    airflow users create \
        --username "${_AIRFLOW_WWW_USER_USERNAME:-admin}" \
        --firstname "Admin" \
        --lastname "Admin" \
        --role "Admin" \
        --email "admin@orc-ai.com" \
        --password "${_AIRFLOW_WWW_USER_PASSWORD:-admin}" || true
}

# Set up directory permissions
setup_directories() {
    echo "Setting up directories..."

    # Create necessary directories
    mkdir -p /opt/airflow/dags
    mkdir -p /opt/airflow/plugins
    mkdir -p /opt/airflow/logs
    mkdir -p /opt/airflow/data/bronze
    mkdir -p /opt/airflow/data/silver
    mkdir -p /opt/airflow/models
    mkdir -p /opt/airflow/test

    # Set appropriate permissions
    chown -R airflow:root /opt/airflow/dags
    chown -R airflow:root /opt/airflow/plugins
    chown -R airflow:root /opt/airflow/logs
    chown -R airflow:root /opt/airflow/data
    chown -R airflow:root /opt/airflow/models
    chown -R airflow:root /opt/airflow/test
}

# Configure environment variables
configure_environment() {
    echo "Configuring environment..."

    # Set default values if not provided
    export AIRFLOW__CORE__EXECUTOR=${AIRFLOW__CORE__EXECUTOR:-LocalExecutor}
    export AIRFLOW__CORE__SQL_ALCHEMY_CONN=${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:-sqlite:////opt/airflow/airflow.db}
    export AIRFLOW__CORE__LOAD_EXAMPLES=${AIRFLOW__CORE__LOAD_EXAMPLES:-False}
    export AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=${AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION:-True}

    # Set Python path to include custom modules
    export PYTHONPATH="${PYTHONPATH}:/opt/airflow/dags:/opt/airflow/plugins"

    # Configure Dask if needed
    if [ -n "$DASK_SCHEDULER_ADDRESS" ]; then
        export DASK_SCHEDULER_ADDRESS=${DASK_SCHEDULER_ADDRESS}
    fi
}

# Wait for dependencies based on the service being started
wait_for_dependencies() {
    local command=$1

    case $command in
        "webserver"|"scheduler"|"worker"|"flower")
            # Wait for PostgreSQL
            if [[ $AIRFLOW__DATABASE__SQL_ALCHEMY_CONN == postgresql* ]]; then
                wait_for_service postgres 5432 PostgreSQL
            fi

            # Wait for Redis if using Celery
            if [[ $AIRFLOW__CORE__EXECUTOR == "CeleryExecutor" ]]; then
                wait_for_service redis 6379 Redis
            fi
            ;;
        "streamlit")
            wait_for_service airflow-webserver 8080 "Airflow Webserver"
            wait_for_service neo4j 7687 "Neo4j"
            wait_for_service prometheus 9090 "Prometheus"
            ;;
    esac
}

# Setup synthetic data if needed
setup_synthetic_data() {
    echo "Setting up synthetic data generation..."

    # Create sample synthetic data configuration
    cat > /opt/airflow/data/synthetic_config.yaml << EOF
# Synthetic Data Generation Configuration
tables:
  customers:
    rows: 1000
    columns:
      customer_id:
        type: "sequence"
        start: 1
      name:
        type: "name"
      email:
        type: "email"
      phone:
        type: "phone_number"
      created_at:
        type: "date_between"
        start_date: "-2y"
        end_date: "today"

  transactions:
    rows: 5000
    columns:
      transaction_id:
        type: "sequence"
        start: 1
      customer_id:
        type: "random_int"
        min: 1
        max: 1000
      amount:
        type: "random_int"
        min: 10
        max: 1000
      transaction_date:
        type: "date_between"
        start_date: "-1y"
        end_date: "today"
      category:
        type: "random_element"
        elements: ["food", "transport", "entertainment", "shopping", "utilities"]
EOF
}

# Create sample DAG if none exists
create_sample_dag() {
    if [ ! -f /opt/airflow/dags/sample_orc_ai_dag.py ]; then
        echo "Creating sample ORC AI DAG..."
        cat > /opt/airflow/dags/sample_orc_ai_dag.py << 'EOF'
"""
Sample ORC AI DAG - Demonstrates the basic workflow orchestration
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

# Default arguments for the DAG
default_args = {
    'owner': 'orc-ai',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Create the DAG
dag = DAG(
    'sample_orc_ai_workflow',
    default_args=default_args,
    description='Sample ORC AI workflow for demonstration',
    schedule_interval=timedelta(hours=1),
    catchup=False,
    tags=['orc-ai', 'sample'],
)

def check_system_health():
    """Check system health and dependencies"""
    import logging
    import requests

    logger = logging.getLogger(__name__)

    # Check Neo4j connection
    try:
        from neo4j import GraphDatabase
        driver = GraphDatabase.driver("bolt://neo4j:7687", auth=("neo4j", "password"))
        with driver.session() as session:
            result = session.run("RETURN 1 as test")
            logger.info("Neo4j connection: OK")
        driver.close()
    except Exception as e:
        logger.warning(f"Neo4j connection failed: {e}")

    # Check if other services are responding
    services = [
        ("Prometheus", "http://prometheus:9090/-/healthy"),
        ("Grafana", "http://grafana:3000/api/health"),
    ]

    for service_name, url in services:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                logger.info(f"{service_name} health check: OK")
            else:
                logger.warning(f"{service_name} health check: FAILED (status: {response.status_code})")
        except Exception as e:
            logger.warning(f"{service_name} health check: FAILED ({e})")

def simulate_ai_reasoning():
    """Simulate AI reasoning task"""
    import logging
    import time
    import random

    logger = logging.getLogger(__name__)
    logger.info("Starting AI reasoning simulation...")

    # Simulate processing time
    processing_time = random.uniform(2, 8)
    time.sleep(processing_time)

    # Simulate decision making
    decisions = ["optimize_workflow", "scale_resources", "alert_anomaly", "continue_monitoring"]
    decision = random.choice(decisions)

    logger.info(f"AI reasoning completed. Decision: {decision}")
    return decision

def process_knowledge_graph():
    """Process knowledge graph operations"""
    import logging

    logger = logging.getLogger(__name__)
    logger.info("Processing knowledge graph operations...")

    # This would contain actual Neo4j operations
    logger.info("Knowledge graph processing completed")

# Define tasks
health_check = PythonOperator(
    task_id='system_health_check',
    python_callable=check_system_health,
    dag=dag,
)

ai_reasoning = PythonOperator(
    task_id='ai_reasoning_simulation',
    python_callable=simulate_ai_reasoning,
    dag=dag,
)

knowledge_graph_task = PythonOperator(
    task_id='knowledge_graph_processing',
    python_callable=process_knowledge_graph,
    dag=dag,
)

system_status = BashOperator(
    task_id='system_status_report',
    bash_command='echo "ORC AI workflow completed successfully at $(date)"',
    dag=dag,
)

# Set task dependencies
health_check >> [ai_reasoning, knowledge_graph_task] >> system_status
EOF
    fi
}

# Main execution logic
main() {
    local command=${1:-"webserver"}

    echo "Starting ORC AI Prototype - Command: $command"

    # Configure environment
    configure_environment

    # Wait for dependencies
    wait_for_dependencies "$command"

    case $command in
        "webserver")
            # Setup directories and initialize DB for webserver
            setup_directories

            # Initialize Airflow DB only if not already done
            if [ "${_AIRFLOW_DB_UPGRADE}" == "true" ]; then
                initialize_airflow_db
            fi

            # Create sample DAG
            create_sample_dag

            # Setup synthetic data
            setup_synthetic_data

            echo "Starting Airflow Webserver..."
            exec airflow webserver --port 8080
            ;;

        "scheduler")
            echo "Starting Airflow Scheduler..."
            exec airflow scheduler
            ;;

        "worker")
            echo "Starting Airflow Celery Worker..."
            exec airflow celery worker
            ;;

        "flower")
            echo "Starting Airflow Celery Flower..."
            exec airflow celery flower --port 5555
            ;;

        "streamlit")
            echo "Starting Streamlit Dashboard..."
            exec streamlit run /app/dashboard/main.py --server.port=8501 --server.address=0.0.0.0
            ;;

        *)
            echo "Executing command: $*"
            exec "$@"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
