#!/usr/bin/env python3
"""Download daily weather observations and load them into PostgreSQL."""

import logging
import os
import sys
import time
from datetime import date
from typing import Any, Dict, List
from urllib.parse import urlencode

import psycopg2
import requests
from psycopg2 import sql
from psycopg2.extras import execute_values


API_BASE_URL = "https://keskkonnaandmed.envir.ee"
API_SERVICE = "/f_kliima_paev"

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "db")
POSTGRES_DATABASE = os.getenv("POSTGRES_DB", "weather_deaths_traffic")
POSTGRES_USER = os.getenv("POSTGRES_USER", "pipeline")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "password")
TARGET_TABLE = os.getenv("WEATHER_TABLE", "weather")

START_YEAR = int(os.getenv("MIN_YEAR", "2020"))
REQUEST_DELAY_SECONDS = 0.5

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)


def month_sequence(
    start_year: int,
    start_month: int,
    end_year: int,
    end_month: int,
):
    """Generate year-month pairs within the requested period."""

    year = start_year
    month = start_month

    while (year, month) <= (end_year, end_month):
        yield year, month

        month += 1

        if month == 13:
            month = 1
            year += 1


def fetch_month(year: int, month: int) -> List[Dict[str, Any]]:
    """Download one month of weather observations."""

    # These names are controlled by the Estonian source API.
    parameters = [
        ("aasta", f"eq.{year}"),
        ("kuu", f"eq.{month}"),
    ]

    url = API_BASE_URL + API_SERVICE + "?" + urlencode(parameters)

    response = requests.get(url, timeout=60)
    response.raise_for_status()

    data = response.json()

    if not isinstance(data, list):
        raise TypeError(
            f"Unexpected weather response for {year}-{month:02d}"
        )

    return data


def transform_row(row: Dict[str, Any]):
    """Translate source fields into English database columns."""

    return (
        row.get("jaam_kood"),
        row.get("jaam_nimi"),
        row.get("aasta"),
        row.get("kuu"),
        row.get("paev"),
        row.get("element_kood"),
        row.get("element_nimi_eng"),
        row.get("element_yhik_eng"),
        row.get("vaartus"),
        row.get("avaandmed_ts"),
    )


def load_weather() -> None:
    """Download all months and safely refresh the weather table."""

    today = date.today()

    connection = psycopg2.connect(
        host=POSTGRES_HOST,
        database=POSTGRES_DATABASE,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
    )

    total_rows = 0

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    """
                    CREATE TABLE IF NOT EXISTS {} (
                        id BIGSERIAL PRIMARY KEY,
                        station_code TEXT,
                        station_name TEXT,
                        observation_year TEXT,
                        observation_month TEXT,
                        observation_day TEXT,
                        metric_code TEXT,
                        metric_name TEXT,
                        metric_unit TEXT,
                        metric_value TEXT,
                        source_updated_at TEXT
                    )
                    """
                ).format(sql.Identifier(TARGET_TABLE))
            )

            cursor.execute(
                """
                CREATE TEMP TABLE weather_stage (
                    station_code TEXT,
                    station_name TEXT,
                    observation_year TEXT,
                    observation_month TEXT,
                    observation_day TEXT,
                    metric_code TEXT,
                    metric_name TEXT,
                    metric_unit TEXT,
                    metric_value TEXT,
                    source_updated_at TEXT
                )
                """
            )

            for year, month in month_sequence(
                START_YEAR,
                1,
                today.year,
                today.month,
            ):
                logging.info("Downloading weather for %s-%02d", year, month)

                data = fetch_month(year, month)

                if not data:
                    logging.warning(
                        "No weather data for %s-%02d",
                        year,
                        month,
                    )
                    continue

                records = [transform_row(row) for row in data]

                execute_values(
                    cursor,
                    """
                    INSERT INTO weather_stage (
                        station_code,
                        station_name,
                        observation_year,
                        observation_month,
                        observation_day,
                        metric_code,
                        metric_name,
                        metric_unit,
                        metric_value,
                        source_updated_at
                    )
                    VALUES %s
                    """,
                    records,
                )

                total_rows += len(records)
                logging.info(
                    "Prepared %s rows; total %s",
                    len(records),
                    total_rows,
                )

                time.sleep(REQUEST_DELAY_SECONDS)

            if total_rows == 0:
                raise ValueError("No weather rows were downloaded")

            cursor.execute("SELECT COUNT(*) FROM weather_stage")
            staged_count = cursor.fetchone()[0]

            if staged_count != total_rows:
                raise ValueError(
                    f"Expected {total_rows} staged rows, found {staged_count}"
                )

            cursor.execute(
                sql.SQL("TRUNCATE TABLE {} RESTART IDENTITY").format(
                    sql.Identifier(TARGET_TABLE)
                )
            )

            cursor.execute(
                sql.SQL(
                    """
                    INSERT INTO {} (
                        station_code,
                        station_name,
                        observation_year,
                        observation_month,
                        observation_day,
                        metric_code,
                        metric_name,
                        metric_unit,
                        metric_value,
                        source_updated_at
                    )
                    SELECT
                        station_code,
                        station_name,
                        observation_year,
                        observation_month,
                        observation_day,
                        metric_code,
                        metric_name,
                        metric_unit,
                        metric_value,
                        source_updated_at
                    FROM weather_stage
                    """
                ).format(sql.Identifier(TARGET_TABLE))
            )

        connection.commit()

        logging.info(
            "Successfully loaded %s rows into %s",
            total_rows,
            TARGET_TABLE,
        )
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def main() -> None:
    """Run weather ingestion."""

    try:
        load_weather()
    except Exception:
        logging.exception("Weather ingestion failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
