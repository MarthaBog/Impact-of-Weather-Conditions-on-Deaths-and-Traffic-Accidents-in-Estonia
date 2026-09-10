#!/bin/bash

set -e

cd /app

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Pipeline started"

log_message "Downloading traffic-accident data"
python scripts/download_traffic.py

log_message "Downloading mortality data"
python scripts/download_deaths.py

log_message "Downloading weather data"
python scripts/download_weather.py

log_message "Building and testing dbt models"
dbt build --profiles-dir .

log_message "Pipeline completed successfully"