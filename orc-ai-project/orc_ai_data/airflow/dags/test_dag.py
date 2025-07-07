    from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

# Default arguments for the DAG
default_args = {
    'owner': 'orc-ai',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG - Note: schedule_interval is now 'schedule' in Airflow 3.0
dag = DAG(
    'test_dag',
    default_args=default_args,
    description='A simple test DAG for ORC AI',
    schedule=timedelta(days=1),  # Changed from schedule_interval to schedule
    catchup=False,
    tags=['test', 'orc-ai'],
)

def hello_world():
    """Simple Python function"""
    print("Hello World from ORC AI!")
    return "Hello World from ORC AI!"

def print_context(**context):
    """Print the Airflow context"""
    print(f"Current DAG: {context['dag'].dag_id}")
    print(f"Current Task: {context['task'].task_id}")
    print(f"Execution Date: {context['execution_date']}")
    return "Context printed successfully"

# Task 1: Simple bash command
task1 = BashOperator(
    task_id='print_date',
    bash_command='date',
    dag=dag,
)

# Task 2: Python function
task2 = PythonOperator(
    task_id='hello_world_task',
    python_callable=hello_world,
    dag=dag,
)

# Task 3: Print context
task3 = PythonOperator(
    task_id='print_context_task',
    python_callable=print_context,
    dag=dag,
)

# Task 4: Another bash command
task4 = BashOperator(
    task_id='print_working_directory',
    bash_command='pwd && ls -la',
    dag=dag,
)

# Set task dependencies
task1 >> task2 >> task3 >> task4