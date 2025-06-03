#!/bin/bash

# ORC AI Prototype Startup Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if Docker/Podman is available
check_container_runtime() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        CONTAINER_RUNTIME="docker"
        COMPOSE_CMD="docker-compose"
        print_status $GREEN "✓ Docker detected and running"
    elif command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
        COMPOSE_CMD="podman-compose"
        print_status $GREEN "✓ Podman detected"
    else
        print_status $RED "✗ Neither Docker nor Podman found. Please install one of them."
        exit 1
    fi
    
    # Check if compose is available
    if ! command -v $COMPOSE_CMD &> /dev/null; then
        print_status $RED "✗ ${COMPOSE_CMD} not found. Please install docker-compose or podman-compose."
        exit 1
    fi
}

# Function to generate Airflow Fernet key
generate_fernet_key() {
    if command -v python3 &> /dev/null; then
        python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    else
        # Fallback to a pre-generated key (not recommended for production)
        echo "dGhpc19pc19hX3NhbXBsZV9mZXJuZXRfa2V5X25vdF9mb3JfcHJvZA=="
    fi
}

# Function to setup environment file
setup_environment() {
    if [ ! -f .env ]; then
        print_status $YELLOW "Creating .env file..."
        
        # Generate Fernet key
        FERNET_KEY=$(generate_fernet_key)
        
        # Create .env file with generated key
        sed "s/your_fernet_key_here_32_chars_long/$FERNET_KEY/" .env.template > .env 2>/dev/null || cp .env .env.backup
        
        print_status $GREEN "✓ .env file created. Please update it with your API keys."
    else
        print_status $GREEN "✓ .env file already exists"
    fi
}

# Function to create necessary directories
create_directories() {
    print_status $YELLOW "Creating project directories..."
    
    directories=(
        "podman/data/bronze"
        "podman/data/silver" 
        "podman/code/dags"
        "podman/code/plugins"
        "podman/code/dashboard"
        "podman/model"
        "podman/test"
        "podman/temp"
        "podman/config"
        "podman/config/grafana/provisioning/dashboards"
        "podman/config/grafana/provisioning/datasources"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_status $GREEN "✓ Created directory: $dir"
    done
    
    # Set appropriate permissions for Airflow
    if [ "$CONTAINER_RUNTIME" = "docker" ]; then
        # For Docker, set UID 50000 (airflow user)
        sudo chown -R 50000:0 podman/code podman/temp 2>/dev/null || {
            print_status $YELLOW "⚠ Could not set permissions. You may need to run: sudo chown -R 50000:0 podman/code podman/temp"
        }
    fi
}

# Function to create sample Streamlit dashboard
create_sample_dashboard() {
    if [ ! -f podman/code/dashboard/main.py ]; then
        print_status $YELLOW "Creating sample Streamlit dashboard..."
        
        cat > podman/code/dashboard/main.py << 'EOF'
import streamlit as st
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import os

# Page configuration
st.set_page_config(
    page_title="ORC AI Prototype Dashboard",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Title and description
st.title("🤖 ORC AI Prototype Dashboard")
st.markdown("---")

# Sidebar
st.sidebar.title("Navigation")
page = st.sidebar.selectbox("Choose a page", ["Overview", "Workflows", "System Health", "AI Insights"])

def get_airflow_dags():
    """Fetch DAGs from Airflow API"""
    try:
        # This would connect to actual Airflow API
        # For now, return sample data
        return [
            {"dag_id": "sample_orc_ai_workflow", "is_active": True, "last_run": "2024-01-15 10:30:00"},
            {"dag_id": "knowledge_graph_update", "is_active": True, "last_run": "2024-01-15 09:15:00"},
            {"dag_id": "ai_reasoning_pipeline", "is_active": False, "last_run": "2024-01-14 18:45:00"}
        ]
    except Exception as e:
        st.error(f"Error fetching DAGs: {e}")
        return []

def show_overview():
    st.header("System Overview")
    
    # Metrics row
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Active DAGs", "3", "1")
    
    with col2:
        st.metric("Running Tasks", "12", "-2")
    
    with col3:
        st.metric("Success Rate", "94.2%", "1.2%")
    
    with col4:
        st.metric("Avg Runtime", "8.5 min", "-1.2 min")
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Task Execution Trends")
        # Sample data
        dates = pd.date_range(start='2024-01-01', end='2024-01-15', freq='D')
        tasks = [12, 15, 18, 14, 20, 22, 25, 19, 16, 24, 28, 31, 27, 23, 26]
        
        fig = px.line(x=dates, y=tasks, title="Daily Task Executions")
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("System Resource Usage")
        # Sample resource data
        resources = ['CPU', 'Memory', 'Disk', 'Network']
        usage = [65, 78, 45, 32]
        
        fig = go.Figure(go.Bar(x=resources, y=usage))
        fig.update_layout(title="Resource Utilization (%)", yaxis_range=[0, 100])
        st.plotly_chart(fig, use_container_width=True)

def show_workflows():
    st.header("Workflow Management")
    
    dags = get_airflow_dags()
    
    if dags:
        df = pd.DataFrame(dags)
        st.dataframe(df, use_container_width=True)
    else:
        st.warning("No workflows found or unable to connect to Airflow.")

def show_system_health():
    st.header("System Health Monitor")
    
    # Service status
    services = [
        {"name": "Airflow", "status": "✅ Running", "uptime": "2d 14h"},
        {"name": "Neo4j", "status": "✅ Running", "uptime": "2d 14h"},
        {"name": "Postgres", "status": "✅ Running", "uptime": "2d 14h"},
        {"name": "Redis", "status": "✅ Running", "uptime": "2d 14h"},
        {"name": "Kafka", "status": "⚠️ Warning", "uptime": "1d 8h"},
        {"name": "Dask", "status": "✅ Running", "uptime": "2d 14h"}
    ]
    
    df_services = pd.DataFrame(services)
    st.dataframe(df_services, use_container_width=True)
    
    # Health metrics over time
    st.subheader("Health Metrics Trends")
    
    # Sample health data
    times = pd.date_range(start='2024-01-15 00:00', end='2024-01-15 23:59', freq='H')
    cpu_usage = [45 + i*2 + (i%6)*5 for i in range(len(times))]
    memory_usage = [60 + i*1.5 + (i%4)*3 for i in range(len(times))]
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=times, y=cpu_usage, name='CPU Usage'))
    fig.add_trace(go.Scatter(x=times, y=memory_usage, name='Memory Usage'))
    fig.update_layout(title="System Resource Usage (24h)", yaxis_title="Usage (%)")
    st.plotly_chart(fig, use_container_width=True)

def show_ai_insights():
    st.header("AI Insights & Analytics")
    
    # AI Decision Analytics
    st.subheader("AI Decision Distribution")
    
    decisions = ['Optimize Workflow', 'Scale Resources', 'Alert Anomaly', 'Continue Monitoring']
    counts = [45, 23, 12, 78]
    
    fig = px.pie(values=counts, names=decisions, title="AI Decision Types (Last 30 Days)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Knowledge Graph Stats
    st.subheader("Knowledge Graph Statistics")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Total Nodes", "1,247", "23")
    
    with col2:
        st.metric("Total Relationships", "3,891", "67")
    
    with col3:
        st.metric("Graph Density", "0.68", "0.02")

# Main app logic
if page == "Overview":
    show_overview()
elif page == "Workflows":
    show_workflows()
elif page == "System Health":
    show_system_health()
elif page == "AI Insights":
    show_ai_insights()

# Footer
st.markdown("---")
st.markdown("*ORC AI Prototype Dashboard - Last updated: {}*".format(datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
EOF
        
        print_status $GREEN "✓ Sample Streamlit dashboard created"
    fi
}

# Function to start services
start_services() {
    print_status $YELLOW "Starting ORC AI Prototype services..."
    
    # Start core services first
    print_status $BLUE "Starting core services (postgres, redis, neo4j)..."
    $COMPOSE_CMD up -d postgres redis neo4j
    
    # Wait a bit for databases to initialize
    sleep 10
    
    # Initialize Airflow
    print_status $BLUE "Initializing Airflow database..."
    $COMPOSE_CMD run --rm airflow-init
    
    # Start remaining services
    print_status $BLUE "Starting remaining services..."
    $COMPOSE_CMD up -d
    
    print_status $GREEN "✓ All services started successfully!"
}

# Function to show service URLs
show_service_urls() {
    print_status $GREEN "\n🎉 ORC AI Prototype is now running!"
    print_status $BLUE "\nAccess the following services:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Airflow Webserver:    http://localhost:8080 (admin/admin_password_2024)"
    echo "🔍 Streamlit Dashboard:  http://localhost:8501"
    echo "📊 Grafana:              http://localhost:3000 (admin/grafana_password_2024)"
    echo "📈 Prometheus:           http://localhost:9090"
    echo "🌸 Airflow Flower:       http://localhost:5555"
    echo "🗄️  Neo4j Browser:        http://localhost:7474 (neo4j/neo4j_password_2024)"
    echo "🔐 Keycloak:             http://localhost:8090 (admin/keycloak_password_2024)"
    echo "⚡ Dask Dashboard:       http://localhost:8787"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_status $YELLOW "\n📝 Next Steps:"
    echo "1. Update your API keys in the .env file"
    echo "2. Visit the Airflow UI to explore sample DAGs"
    echo "3. Check the Streamlit dashboard for system overview"
    echo "4. Explore the Neo4j browser for knowledge graph visualization"
    
    print_status $YELLOW "\n🛠️  Management Commands:"
    echo "• View logs:     $COMPOSE_CMD logs -f [service_name]"
    echo "• Stop services: $COMPOSE_CMD down"
    echo "• Restart:       $COMPOSE_CMD restart [service_name]"
    echo "• Scale workers: $COMPOSE_CMD up -d --scale airflow-worker=3"
}

# Main execution
main() {
    print_status $BLUE "🚀 Starting ORC AI Prototype Setup..."
    echo
    
    # Check prerequisites
    check_container_runtime
    
    # Setup environment
    setup_environment
    
    # Create directories
    create_directories
    
    # Create sample dashboard
    create_sample_dashboard
    
    # Ask user if they want to start services
    read -p "Do you want to start all services now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_services
        show_service_urls
    else
        print_status $YELLOW "Setup completed. Run '$COMPOSE_CMD up -d' to start services when ready."
    fi
}

# Handle script arguments
case "${1:-}" in
    "start")
        check_container_runtime
        start_services
        show_service_urls
        ;;
    "stop")
        check_container_runtime
        print_status $YELLOW "Stopping all services..."
        $COMPOSE_CMD down
        print_status $GREEN "✓ All services stopped"
        ;;
    "restart")
        check_container_runtime
        print_status $YELLOW "Restarting all services..."
        $COMPOSE_CMD restart
        print_status $GREEN "✓ All services restarted"