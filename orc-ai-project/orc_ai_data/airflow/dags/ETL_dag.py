from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.sensors.filesystem import FileSensor
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'orc-ai-team',
    'depends_on_past': False,
    'start_date': datetime(2025, 7, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=3),
    'max_active_runs': 1,
}

# DAG 1: Daily processing
daily_dag = DAG(
    'orc_ai_daily_processing',
    default_args=default_args,
    description='Daily data processing for ORC AI',
    schedule="@daily",  # Runs daily at midnight
    catchup=False,
    tags=['orc-ai', 'daily', 'processing'],
)

# DAG 2: Hourly monitoring
hourly_dag = DAG(
    'orc_ai_hourly_monitoring',
    default_args=default_args,
    description='Hourly system monitoring',
    schedule="@hourly",  # Runs every hour
    catchup=False,
    tags=['orc-ai', 'monitoring', 'hourly'],
)

# DAG 3: Custom cron schedule
custom_dag = DAG(
    'orc_ai_custom_schedule',
    default_args=default_args,
    description='Custom scheduled tasks',
    schedule="0 */6 * * *",  # Every 6 hours
    catchup=False,
    tags=['orc-ai', 'custom'],
)

# DAG 4: Manual trigger only
manual_dag = DAG(
    'orc_ai_manual_trigger',
    default_args=default_args,
    description='Manual trigger only tasks',
    schedule=None,  # Manual trigger only
    catchup=False,
    tags=['orc-ai', 'manual'],
)

# Python functions
def data_quality_check(**context):
    """Simulate data quality check"""
    logger.info("Running data quality checks...")
    
    # Simulate some checks
    checks = [
        "Null value validation",
        "Data type validation", 
        "Range validation",
        "Duplicate detection"
    ]
    
    for check in checks:
        logger.info(f"✓ {check} - PASSED")
    
    return "All data quality checks passed"

def system_health_check(**context):
    """Check system health metrics"""
    logger.info("Checking system health...")
    
    import psutil
    
    # Get system metrics
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    logger.info(f"CPU Usage: {cpu_percent}%")
    logger.info(f"Memory Usage: {memory.percent}%")
    logger.info(f"Disk Usage: {disk.percent}%")
    
    # Alert if any metric is too high
    if cpu_percent > 80 or memory.percent > 80 or disk.percent > 80:
        logger.warning("System resources are running high!")
    
    return "System health check completed"

def ai_model_training(**context):
    """Simulate AI model training"""
    logger.info("Starting AI model training...")
    
    # Simulate training steps
    steps = [
        "Data preprocessing",
        "Feature engineering",
        "Model training",
        "Model validation",
        "Model deployment"
    ]
    
    for i, step in enumerate(steps, 1):
        logger.info(f"Step {i}/5: {step}")
    
    logger.info("AI model training completed successfully!")
    return "Model training completed"

# Tasks for daily_dag
start_daily = EmptyOperator(
    task_id='start_daily_processing',
    dag=daily_dag,
)

data_extraction = BashOperator(
    task_id='extract_data',
    bash_command='echo "Extracting data from sources..." && sleep 2',
    dag=daily_dag,
)

data_transformation = PythonOperator(
    task_id='transform_data',
    python_callable=data_quality_check,
    dag=daily_dag,
)

data_loading = BashOperator(
    task_id='load_data',
    bash_command='echo "Loading data to warehouse..." && sleep 2',
    dag=daily_dag,
)

end_daily = EmptyOperator(
    task_id='end_daily_processing',
    dag=daily_dag,
)

# Tasks for hourly_dag
health_check = PythonOperator(
    task_id='system_health_check',
    python_callable=system_health_check,
    dag=hourly_dag,
)

log_rotation = BashOperator(
    task_id='rotate_logs',
    bash_command='echo "Rotating system logs..." && find /opt/airflow/logs -name "*.log" -mtime +7 -exec echo "Would rotate: {}" \;',
    dag=hourly_dag,
)

# Tasks for custom_dag
ai_training = PythonOperator(
    task_id='ai_model_training',
    python_callable=ai_model_training,
    dag=custom_dag,
)

model_evaluation = BashOperator(
    task_id='evaluate_model',
    bash_command='echo "Evaluating model performance..." && sleep 3',
    dag=custom_dag,
)

# Tasks for manual_dag
emergency_backup = BashOperator(
    task_id='emergency_backup',
    bash_command='echo "Creating emergency backup..." && sleep 5',
    dag=manual_dag,
)

system_maintenance = BashOperator(
    task_id='system_maintenance',
    bash_command='echo "Performing system maintenance..." && sleep 10',
    dag=manual_dag,
)

# Set dependencies
# Daily DAG flow
start_daily >> data_extraction >> data_transformation >> data_loading >> end_daily

# Hourly DAG flow
health_check >> log_rotation

# Custom DAG flow
ai_training >> model_evaluation

# Manual DAG flow
emergency_backup >> system_maintenance