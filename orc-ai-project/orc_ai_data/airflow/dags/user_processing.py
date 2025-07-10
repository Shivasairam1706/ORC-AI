from airflow.sdk import dag, task
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.sdk.bases.sensor import PokeReturnValue
from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime, timedelta
import csv
import os
import tempfile
import requests
import logging

# DAG default arguments
default_args = {
    'owner': 'data_team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

@dag(
    dag_id='user_processing_dag',
    default_args=default_args,
    description='Process user data from API and store in PostgreSQL',
    schedule=timedelta(hours=1),
    catchup=False,
    tags=['users', 'api', 'postgres']
)
def user_processing():
    
    create_table = SQLExecuteQueryOperator(
        task_id="create_table",
        conn_id="postgres",
        sql="""
        CREATE TABLE IF NOT EXISTS users (
            id INT PRIMARY KEY,
            firstname VARCHAR(255),
            lastname VARCHAR(255),
            email VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    
    @task.sensor(poke_interval=30, timeout=300)
    def is_api_available() -> PokeReturnValue:
        """Check if the API is available and return user data if successful"""
        try:
            response = requests.get(
                "https://raw.githubusercontent.com/marclamberti/datasets/refs/heads/main/fakeuser.json",
                timeout=10
            )
            logging.info(f"API response status: {response.status_code}")
            
            if response.status_code == 200:
                fake_user = response.json()
                return PokeReturnValue(is_done=True, xcom_value=fake_user)
            else:
                logging.warning(f"API returned status code: {response.status_code}")
                return PokeReturnValue(is_done=False, xcom_value=None)
                
        except requests.exceptions.RequestException as e:
            logging.error(f"API request failed: {str(e)}")
            return PokeReturnValue(is_done=False, xcom_value=None)
    
    @task
    def extract_user(fake_user):
        """Extract relevant user information from API response"""
        if not fake_user:
            raise ValueError("No user data received from API")
            
        try:
            extracted_user = {
                "id": fake_user["id"],
                "firstname": fake_user["personalInfo"]["firstName"],
                "lastname": fake_user["personalInfo"]["lastName"],
                "email": fake_user["personalInfo"]["email"],
            }
            logging.info(f"Extracted user: {extracted_user['email']}")
            return extracted_user
            
        except KeyError as e:
            logging.error(f"Missing key in user data: {str(e)}")
            raise ValueError(f"Invalid user data structure: missing {str(e)}")
        
    @task
    def process_user(user_info=None):
        """Process user data and save to CSV file"""
        # Handle case when testing individual tasks without upstream data
        if not user_info:
            logging.warning("No user info received, using test data for individual task testing")
            user_info = {
                "id": 999,
                "firstname": "Test",
                "lastname": "User",
                "email": "test.user@example.com",
            }
            
        # Add timestamp to user info
        user_info["created_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Create temporary file
        temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        temp_filename = temp_file.name
        
        try:
            with temp_file as f:
                writer = csv.DictWriter(f, fieldnames=user_info.keys())
                writer.writeheader()
                writer.writerow(user_info)
            
            logging.info(f"User data written to {temp_filename}")
            return temp_filename
            
        except Exception as e:
            # Clean up file if there was an error
            if os.path.exists(temp_filename):
                os.unlink(temp_filename)
            raise RuntimeError(f"Failed to process user data: {str(e)}")
            
    @task
    def store_user(csv_filename=None):
        """Store user data from CSV file into PostgreSQL"""
        # Handle case when testing individual tasks
        if not csv_filename:
            logging.warning("No CSV filename provided, creating test data for individual task testing")
            test_user = {
                "id": 999,
                "firstname": "Test",
                "lastname": "User", 
                "email": "test.user@example.com",
                "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
            csv_filename = temp_file.name
            
            with temp_file as f:
                writer = csv.DictWriter(f, fieldnames=test_user.keys())
                writer.writeheader()
                writer.writerow(test_user)
        
        if not os.path.exists(csv_filename):
            raise ValueError(f"CSV file not found: {csv_filename}")
            
        try:
            hook = PostgresHook(postgres_conn_id="postgres_EDA")
            
            # Use copy_expert to load data from CSV
            hook.copy_expert(
                sql="COPY users FROM STDIN WITH CSV HEADER",
                filename=csv_filename
            )
            
            logging.info("User data successfully stored in PostgreSQL")
            
        except Exception as e:
            logging.error(f"Failed to store user data: {str(e)}")
            raise RuntimeError(f"Database operation failed: {str(e)}")
            
        finally:
            # Clean up temporary file
            if os.path.exists(csv_filename):
                os.unlink(csv_filename)
                logging.info(f"Cleaned up temporary file: {csv_filename}")
    
    # Define task dependencies
    fake_user = is_api_available()
    user_info = extract_user(fake_user)
    csv_file = process_user(user_info)
    
    # Set up the workflow
    create_table >> fake_user >> user_info >> csv_file >> store_user(csv_file)

# Instantiate the DAG
dag_instance = user_processing()