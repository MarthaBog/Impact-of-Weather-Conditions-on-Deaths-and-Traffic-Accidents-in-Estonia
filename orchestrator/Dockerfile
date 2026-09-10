FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY dbt-requirements.txt /tmp/dbt-requirements.txt
COPY scripts/requirements.txt /tmp/ingestion-requirements.txt

RUN pip install --no-cache-dir \
    -r /tmp/dbt-requirements.txt \
    -r /tmp/ingestion-requirements.txt

COPY orchestrator/run.sh /app/orchestrator/run.sh

RUN chmod +x /app/orchestrator/run.sh

ENTRYPOINT ["/app/orchestrator/run.sh"]
