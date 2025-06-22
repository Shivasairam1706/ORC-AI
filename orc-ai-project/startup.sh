#!/bin/bash

# ORC AI Environment Setup Script
# This script creates the required directory structure and sets up initial configurations

echo "🚀 Setting up ORC AI environment..."

# Create base directory structure
echo "📁 Creating directory structure..."
mkdir -p orc_ai_data/{airflow/{dags,logs,plugins},postgres/data,redis/data,prometheus/{config,data},grafana/{data,provisioning/{datasources,dashboards}},jupyter/work}

# Set proper permissions for directories
echo "🔒 Setting directory permissions..."
chmod 755 orc_ai_data
chmod -R 755 orc_ai_data/airflow
chmod -R 755 orc_ai_data/prometheus
chmod -R 755 orc_ai_data/grafana

# Create Prometheus configuration
echo "⚙️ Creating Prometheus configuration..."
cat > orc_ai_data/prometheus/config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'orc-ai-monitor'

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
    metrics_path: /metrics

  # Airflow Webserver metrics
  - job_name: 'airflow-webserver'
    static_configs:
      - targets: ['airflow-webserver:8080']
    scrape_interval: 30s
    metrics_path: /admin/metrics
    basic_auth:
      username: 'admin'
      password: 'admin123'

  # Flower Celery monitoring
  - job_name: 'flower'
    static_configs:
      - targets: ['airflow-flower:5555']
    scrape_interval: 30s
    metrics_path: /metrics

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093
EOF

# Create Grafana datasource configuration
echo "📊 Creating Grafana datasource configuration..."
cat > orc_ai_data/grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      prometheusType: Prometheus
      prometheusVersion: 2.45.0
      queryTimeout: 60s
      timeInterval: 15s
    basicAuth: false
    withCredentials: false
    secureJsonFields: {}

  - name: PostgreSQL
    type: postgres
    access: proxy
    url: postgres:5432
    database: airflow
    user: airflow
    secureJsonData:
      password: airflow123
    jsonData:
      sslmode: disable
      maxOpenConns: 100
      maxIdleConns: 100
      connMaxLifetime: 14400
    editable: true
EOF

# Create sample Airflow DAG
echo "📝 Creating sample Airflow DAG..."
cat > orc_ai_data/airflow/dags/orc_ai_sample_dag.py << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
import logging

default_args = {
    'owner': 'orc-ai',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

dag = DAG(
    'orc_ai_sample_workflow',
    default_args=default_args,
    description='ORC AI Sample Workflow',
    schedule_interval=timedelta(minutes=30),
    catchup=False,
    tags=['orc-ai', 'sample']
)

def ai_health_check():
    """Sample AI health check function"""
    logging.info("🤖 ORC AI Health Check - All systems operational!")
    return "AI systems healthy"

def system_metrics():
    """Sample system metrics collection"""
    import psutil
    cpu_percent = psutil.cpu_percent()
    memory_percent = psutil.virtual_memory().percent
    logging.info(f"📊 System Metrics - CPU: {cpu_percent}%, Memory: {memory_percent}%")
    return {"cpu": cpu_percent, "memory": memory_percent}

# Task 1: System Health Check
health_check_task = PythonOperator(
    task_id='ai_health_check',
    python_callable=ai_health_check,
    dag=dag
)

# Task 2: System Metrics Collection
metrics_task = PythonOperator(
    task_id='system_metrics',
    python_callable=system_metrics,
    dag=dag
)

# Task 3: Data Processing Simulation
data_processing_task = BashOperator(
    task_id='data_processing',
    bash_command='echo "🔄 Processing AI workflow data..." && sleep 10 && echo "✅ Data processing complete"',
    dag=dag
)

# Task 4: AI Model Status
ai_status_task = BashOperator(
    task_id='ai_model_status',
    bash_command='echo "🧠 Checking AI model status..." && echo "✅ AI models ready"',
    dag=dag
)

# Define task dependencies
health_check_task >> [metrics_task, data_processing_task]
[metrics_task, data_processing_task] >> ai_status_task
EOF

# Create environment file
echo "🔧 Creating environment configuration..."
cat > .env << 'EOF'
# ORC AI Environment Configuration
AIRFLOW_UID=50000
AIRFLOW_GID=0

# Database Configuration
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow123
POSTGRES_DB=airflow

# Airflow Configuration
AIRFLOW_ADMIN_USER=admin
AIRFLOW_ADMIN_PASSWORD=admin123

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# Jupyter Configuration
JUPYTER_TOKEN=airflow123

# Redis Configuration
REDIS_PASSWORD=

# Generate Fernet Key for Airflow (replace with actual generated key)
AIRFLOW_FERNET_KEY=your-fernet-key-here-replace-with-32-character-key
EOF

# Create a README for the environment
echo "📖 Creating README..."
cat > README.md << 'EOF'
# 🚀 ORC AI Environment

This Docker Compose environment provides a complete AI-powered workflow orchestration platform.

## Services

- **Airflow**: Workflow orchestration (http://localhost:8080)
  - Username: admin
  - Password: admin123

- **Flower**: Celery monitoring (http://localhost:5555)

- **Prometheus**: Metrics collection (http://localhost:9090)

- **Grafana**: Visualization dashboards (http://localhost:3000)
  - Username: admin
  - Password: admin123

- **Jupyter**: Development environment (http://localhost:8888)
  - Token: airflow123

- **PostgreSQL**: Database (localhost:5432)
- **Redis**: Message broker (localhost:6379)

## Quick Start

1. Run setup script: `./setup.sh`
2. Start environment: `docker compose up -d`
3. Access services using URLs above

## Important Notes

- Generate a proper Fernet key for production use
- Update default passwords before production deployment
- All data is persisted in `orc_ai_data/` directory
EOF

echo "✅ ORC AI environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Review and update the Fernet key in docker-compose.yml"
echo "2. Run: docker compose up -d"
echo "3. Access services:"
echo "   - Airflow UI: http://localhost:8080 (admin/admin123)"
echo "   - Grafana: http://localhost:3000 (admin/admin123)"
echo "   - Jupyter: http://localhost:8888 (token: airflow123)"
echo "   - Prometheus: http://localhost:9090"
echo "   - Flower: http://localhost:5555"