#!/usr/bin/env python3
"""Download weekly mortality data and load it into PostgreSQL."""

import logging
import math
import os
import sys
from typing import Any, Dict, Iterator

import psycopg2
import requests
from psycopg2 import sql
from psycopg2.extras import execute_values
from pyjstat import pyjstat


API_URL = "https://andmed.stat.ee/api/v1/et/stat/RV035"

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "db")
POSTGRES_DATABASE = os.getenv("POSTGRES_DB", "weather_deaths_traffic")
POSTGRES_USER = os.getenv("POSTGRES_USER", "pipeline")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "password")
TARGET_TABLE = os.getenv("DEATHS_TABLE", "deaths")

MIN_YEAR = int(os.getenv("MIN_YEAR", "2020"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)


def fetch_metadata() -> Dict[str, Any]:
    """Download dataset metadata from Statistics Estonia."""

    logging.info("Fetching metadata from %s", API_URL)

    response = requests.get(API_URL, timeout=30)
    response.raise_for_status()

    return response.json()


def extract_code(value: Any) -> str:
    """Return a source code from either a dictionary or a plain value."""

    if isinstance(value, dict):
        return str(value.get("code", ""))

    return str(value)


def build_query(metadata: Dict[str, Any]) -> Dict[str, Any]:
    """Build an API query for all dimensions from MIN_YEAR onward."""

    query = []

    for variable in metadata.get("variables", []):
        variable_code = variable.get("code")

        if variable_code == "Vaatlusperiood":
            years = [
                extract_code(value)
                for value in variable.get("values", [])
                if extract_code(value).isdigit()
                and int(extract_code(value)) >= MIN_YEAR
            ]

            if not years:
                raise ValueError(f"No years found from {MIN_YEAR} onward")

            selection = {
                "filter": "item",
                "values": years,
            }
        else:
            selection = {
                "filter": "all",
                "values": ["*"],
            }

        query.append(
            {
                "code": variable_code,
                "selection": selection,
            }
        )

    return {
        "query": query,
        "response": {
            "format": "json-stat2",
        },
    }


def fetch_data(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Download mortality data using a POST request."""

    logging.info("Downloading mortality data")

    response = requests.post(
        API_URL,
        json=payload,
        timeout=120,
    )
    response.raise_for_status()

    return response.json()


def jsonstat_to_rows(json_data: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """Convert JSON-stat2 data into dictionaries."""

    datasets = pyjstat.from_json_stat(json_data)

    if not datasets:
        raise ValueError("The mortality API returned no datasets")

    dataset = datasets[0]

    if hasattr(dataset, "iterrows"):
        for _, row in dataset.iterrows():
            yield row.to_dict()
    elif isinstance(dataset, list):
        yield from dataset
    else:
        raise TypeError("Unsupported JSON-stat2 result type")


def parse_numeric_value(value: Any) -> float | None:
    """Convert a source value to a number while preserving zero."""

    if value is None:
        return None

    if isinstance(value, float) and math.isnan(value):
        return None

    text = str(value).strip()

    if text in ("", "NaN", "nan"):
        return None

    return float(value)


def load_into_postgres(rows: Iterator[Dict[str, Any]]) -> None:
    """Load rows safely and replace the target table after validation."""

    records = []

    for row in rows:
        records.append(
            (
                str(row.get("Näitaja", "")),
                str(row.get("Nädal", "")),
                int(row.get("Vaatlusperiood")),
                str(row.get("Sugu", "")),
                str(row.get("Vanuserühm", "")),
                parse_numeric_value(row.get("value")),
            )
        )

    if not records:
        raise ValueError("No mortality rows were prepared for loading")

    logging.info("Prepared %s mortality rows", len(records))

    connection = psycopg2.connect(
        host=POSTGRES_HOST,
        database=POSTGRES_DATABASE,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
    )

    try:
        with connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        """
                        CREATE TABLE IF NOT EXISTS {} (
                            id BIGSERIAL PRIMARY KEY,
                            indicator TEXT NOT NULL,
                            iso_week_label TEXT NOT NULL,
                            observation_year INTEGER NOT NULL,
                            sex TEXT NOT NULL,
                            age_group TEXT NOT NULL,
                            deaths_count NUMERIC
                        )
                        """
                    ).format(sql.Identifier(TARGET_TABLE))
                )

                cursor.execute(
                    """
                    CREATE TEMP TABLE deaths_stage (
                        indicator TEXT NOT NULL,
                        iso_week_label TEXT NOT NULL,
                        observation_year INTEGER NOT NULL,
                        sex TEXT NOT NULL,
                        age_group TEXT NOT NULL,
                        deaths_count NUMERIC
                    )
                """
                )

                execute_values(
                    cursor,
                    """
                    INSERT INTO deaths_stage (
                        indicator,
                        iso_week_label,
                        observation_year,
                        sex,
                        age_group,
                        deaths_count
                    )
                    VALUES %s
                    """,
                    records,
                )

                cursor.execute("SELECT COUNT(*) FROM deaths_stage")
                staged_count = cursor.fetchone()[0]

                if staged_count == 0:
                    raise ValueError("The mortality staging table is empty")

                cursor.execute(
                    sql.SQL("TRUNCATE TABLE {} RESTART IDENTITY").format(
                        sql.Identifier(TARGET_TABLE)
                    )
                )

                cursor.execute(
                    sql.SQL(
                        """
                        INSERT INTO {} (
                            indicator,
                            iso_week_label,
                            observation_year,
                            sex,
                            age_group,
                            deaths_count
                        )
                        SELECT
                            indicator,
                            iso_week_label,
                            observation_year,
                            sex,
                            age_group,
                            deaths_count
                        FROM deaths_stage
                        """
                    ).format(sql.Identifier(TARGET_TABLE))
                )

        logging.info(
            "Successfully loaded %s rows into %s",
            len(records),
            TARGET_TABLE,
        )
    finally:
        connection.close()


def main() -> None:
    """Run the mortality ingestion process."""

    try:
        metadata = fetch_metadata()
        payload = build_query(metadata)
        json_data = fetch_data(payload)
        rows = jsonstat_to_rows(json_data)
        load_into_postgres(rows)
    except Exception:
        logging.exception("Mortality ingestion failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
