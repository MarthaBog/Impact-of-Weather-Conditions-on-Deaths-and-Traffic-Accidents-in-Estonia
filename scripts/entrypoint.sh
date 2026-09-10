#!/bin/sh

set -e

echo "Starting data ingestion"

echo "Downloading traffic-accident data"
python download_traffic.py

echo "Downloading mortality data"
python download_deaths.py

echo "Downloading weather data"
python download_weather.py

echo "Data ingestion completed successfully"