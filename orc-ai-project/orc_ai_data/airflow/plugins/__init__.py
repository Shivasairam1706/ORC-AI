# orc_ai_data/airflow/plugins/__init__.py

# This init file allows the folder to be recognized as a Python package by Airflow's plugin loader.
# You can add custom plugins in this directory, such as macros, hooks, operators, sensors, etc.

# Example: You can place plugin classes here or import them from submodules.

# Initialize the ORC AI Monitoring and Analysis Module.
# This file configures environment variables, logging, and core service interfaces
# like Redis, PostgreSQL, Prometheus API clients, and any shared utilities.

import os
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up basic logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment variables
POSTGRES_HOST = os.getenv("POSTGRES_HOST")
POSTGRES_PORT = os.getenv("POSTGRES_PORT")
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRES_DB = os.getenv("POSTGRES_DB")

REDIS_HOST = os.getenv("REDIS_HOST")
REDIS_PORT = os.getenv("REDIS_PORT")
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD")

PROMETHEUS_URL = os.getenv("PROMETHEUS_URL")

# Prometheus Metric Tags
PROM_JOB_REGEX = os.getenv("PROM_JOB_REGEX")
DAG_RUN_COUNT = os.getenv("DAG_RUN_COUNT")
TASK_SUCCESS_METRIC = os.getenv("TASK_SUCCESS_METRIC")
TASK_FAILURE_METRIC = os.getenv("TASK_FAILURE_METRIC")
REDIS_UP_METRIC = os.getenv("REDIS_UP_METRIC")
POSTGRES_UP_METRIC = os.getenv("POSTGRES_UP_METRIC")
ACTIVE_DAGS_METRIC = os.getenv("ACTIVE_DAGS_METRIC")
DAG_RUN_DURATION_METRIC = os.getenv("DAG_RUN_DURATION_METRIC")
TASK_STATE_DISTRIBUTION_METRIC = os.getenv("TASK_STATE_DISTRIBUTION_METRIC")
CELERY_WORKERS_METRIC = os.getenv("CELERY_WORKERS_METRIC")

# Redis connection pool and client setup (if needed here)
# PostgreSQL SQLAlchemy setup (if shared across modules)
# Prometheus API client setup (if any shared class for querying Prometheus)

logger.info("ORC AI Monitoring module initialized.")
