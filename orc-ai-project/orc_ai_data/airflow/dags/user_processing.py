from airflow.sdk import dag, task
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.sensors.base import PokeReturnValue
import requests

@dag
def user_preprocessing():
    create_table = SQLExecuteQueryOperator(
        task_id='create_table',
        conn_id='postgres_EDA',
        sql="""
        CREATE TABLE IF NOT EXISTS USERS(
        ID INT PRIMARY KEY,
        FIRSTNAME VARCHAR(255),
        LASTNAME VARCHAR(255),
        EMAIL VARCHAR(255),
        CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )"""
    )
    
    @task.sensor(poke_interval=20, timeout=100)
    def is_api_available() -> PokeReturnValue:
        response = requests.get('https://raw.githubusercontent.com/marclamberti/datasets/refs/heads/main/fakeusers.json')
        print(response.status_code)
        if response.status_code == 200:
            condition = True
            fakeuser = response.json()
        else:
            condition = False
            fakeuser = None
        return PokeReturnValue(is_done=condition, xcom_value=fakeuser)
    
    # Set up task dependencies
    api_check = is_api_available()
    create_table >> api_check

user_preprocessing()