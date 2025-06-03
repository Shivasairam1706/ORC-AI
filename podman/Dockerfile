FROM apache/airflow:2.7.1-python3.10

# Switch to root user to install system dependencies
USER root

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        build-essential \
        default-jdk \
        procps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Switch back to airflow user
USER airflow

# Copy requirements file
COPY requirements.txt /requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /requirements.txt

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
USER root
RUN chmod +x /entrypoint.sh
USER airflow

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]