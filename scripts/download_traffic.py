#!/usr/bin/env python3
"""Download personal-injury traffic accidents and load them into PostgreSQL."""

import csv
import io
import logging
import os
import sys
from datetime import date, datetime, time
from typing import Dict, List, Tuple

import psycopg2
import requests
from psycopg2 import sql
from psycopg2.extras import execute_values


METADATA_URL = (
    "https://avaandmed.eesti.ee/api/datasets/slug/"
    "inimkannatanutega-liiklusonnetuste-andmed"
)

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "db")
POSTGRES_DATABASE = os.getenv("POSTGRES_DB", "weather_deaths_traffic")
POSTGRES_USER = os.getenv("POSTGRES_USER", "pipeline")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "password")
TARGET_TABLE = os.getenv("TRAFFIC_TABLE", "traffic_accidents")

MIN_DATE = datetime.strptime(
    os.getenv("MIN_DATE", "2020-01-01"),
    "%Y-%m-%d",
).date()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)


def find_csv_url() -> str:
    """Find the CSV download URL in dataset metadata."""

    response = requests.get(METADATA_URL, timeout=30)
    response.raise_for_status()

    metadata = response.json()

    for distribution in metadata.get("distributions", []):
        if str(distribution.get("format", "")).upper() != "CSV":
            continue

        urls = distribution.get("accessUrls", [])

        if urls:
            return urls[0]

    raise ValueError("CSV download URL was not found")


def download_csv(download_url: str) -> str:
    """Download the complete source CSV."""

    logging.info("Downloading traffic-accident data")

    response = requests.get(download_url, timeout=120)
    response.raise_for_status()

    response.encoding = response.apparent_encoding or "utf-8"

    return response.text


def parse_datetime(value: str) -> Tuple[date, time | None]:
    """Parse the source accident date and time."""

    value = value.strip()

    supported_formats = (
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%d.%m.%Y %H:%M:%S",
        "%d.%m.%Y %H:%M",
        "%Y-%m-%d",
        "%d.%m.%Y",
    )

    for date_format in supported_formats:
        try:
            parsed = datetime.strptime(value, date_format)

            includes_time = "%H" in date_format

            return (
                parsed.date(),
                parsed.time() if includes_time else None,
            )
        except ValueError:
            continue

    raise ValueError(f"Unsupported accident datetime: {value!r}")


def parse_integer(value: str | None) -> int:
    """Convert an empty source value to zero."""

    if value is None or not value.strip():
        return 0

    return int(value)


def parse_rows(csv_text: str) -> List[Tuple]:
    """Translate source CSV rows into English database fields."""

    reader = csv.DictReader(
        io.StringIO(csv_text),
        delimiter=";",
    )

    records = []

    for source_row_number, row in enumerate(reader, start=2):
        # These field names are controlled by the source CSV.
        observation_date, accident_time = parse_datetime(
            row.get("Toimumisaeg", "")
        )

        if observation_date < MIN_DATE:
            continue

        records.append(
            (
                source_row_number,
                observation_date,
                accident_time,
                row.get("Maakond", "").strip(),
                row.get("Omavalitsus", "").strip(),
                parse_integer(row.get("Hukkunuid")),
                parse_integer(row.get("Vigastatuid")),
            )
        )

    if not records:
        raise ValueError("No traffic-accident rows passed validation")

    return records


def load_into_postgres(records: List[Tuple]) -> None:
    """Safely replace the traffic-accident table."""

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
                            source_row_number INTEGER NOT NULL,
                            accident_date DATE NOT NULL,
                            accident_time TIME,
                            county TEXT,
                            municipality TEXT,
                            killed_count INTEGER NOT NULL,
                            injured_count INTEGER NOT NULL
                        )
                        """
                    ).format(sql.Identifier(TARGET_TABLE))
                )

                cursor.execute(
                    """
                    CREATE TEMP TABLE traffic_stage (
                        source_row_number INTEGER NOT NULL,
                        accident_date DATE NOT NULL,
                        accident_time TIME,
                        county TEXT,
                        municipality TEXT,
                        killed_count INTEGER NOT NULL,
                        injured_count INTEGER NOT NULL
                    )
                    """
                )

                execute_values(
                    cursor,
                    """
                    INSERT INTO traffic_stage (
                        source_row_number,
                        accident_date,
                        accident_time,
                        county,
                        municipality,
                        killed_count,
                        injured_count
                    )
                    VALUES %s
                    """,
                    records,
                )

                cursor.execute("SELECT COUNT(*) FROM traffic_stage")
                staged_count = cursor.fetchone()[0]

                if staged_count != len(records):
                    raise ValueError(
                        f"Expected {len(records)} rows, found {staged_count}"
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
                            source_row_number,
                            accident_date,
                            accident_time,
                            county,
                            municipality,
                            killed_count,
                            injured_count
                        )
                        SELECT
                            source_row_number,
                            accident_date,
                            accident_time,
                            county,
                            municipality,
                            killed_count,
                            injured_count
                        FROM traffic_stage
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
    """Run traffic-accident ingestion."""

    try:
        download_url = find_csv_url()
        csv_text = download_csv(download_url)
        records = parse_rows(csv_text)
        load_into_postgres(records)
    except Exception:
        logging.exception("Traffic-accident ingestion failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
