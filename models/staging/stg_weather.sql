with typed as (
    select
        trim(station_code) as station_code,
        trim(station_name) as station_name,
        make_date(
            observation_year::integer,
            observation_month::integer,
            observation_day::integer
        ) as observation_date,
        trim(metric_code) as metric_code,
        trim(metric_name) as metric_name,
        trim(metric_unit) as metric_unit,
        nullif(trim(metric_value), '')::numeric as metric_value,
        nullif(trim(source_updated_at), '')::timestamptz
            as source_updated_at
    from {{ source('raw', 'weather') }}
),

filtered as (
    select *
    from typed
    where metric_name in (
        'Air temperature (daily avg)',
        'Air temperature (daily max)',
        'Air temperature (daily min)',
        'Precipitation (daily sum)',
        'Wind speed (daily avg)',
        'Sunshine duration (daily sum)'
    )
      and metric_value is not null
)

select
    station_code,
    station_name,
    observation_date,
    extract(isoyear from observation_date)::integer as iso_year,
    extract(week from observation_date)::integer as iso_week,
    {{ generate_week_key(
        "extract(isoyear from observation_date)::integer",
        "extract(week from observation_date)::integer"
    ) }} as week_key,
    metric_code,
    metric_name,
    metric_unit,
    metric_value,
    source_updated_at
from filtered