from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import logging
import random

# Default DAG arguments
default_args = {
    'owner': 'orc-ai',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

# Dummy metric collector function (to be replaced with metrics_collector.py functions)
def collect_and_log_metrics(**kwargs):
    metric_value = random.uniform(0.1, 0.9)  # simulate metric
    logging.info(f"[ORC AI METRIC] Task executed with metric value: {metric_value:.3f}")

# DAG definition
dag = DAG(
    dag_id='orc_ai_sample_dag',
    default_args=default_args,
    description='Sample DAG for ORC AI - Logs custom metrics to stdout',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['orc-ai', 'metrics', 'sample']
)

# Task: Collect metrics
collect_metrics = PythonOperator(
    task_id='collect_and_log_metrics',
    python_callable=collect_and_log_metrics,
    provide_context=True,
    dag=dag
)

collect_metrics
