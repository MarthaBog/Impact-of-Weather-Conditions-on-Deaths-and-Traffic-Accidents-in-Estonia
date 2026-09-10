select
    week_key,
    iso_year,
    iso_week,
    county_name,

    avg(accident_count) over history_window
        as accident_count_historical_average,

    avg(injured_count) over history_window
        as injured_count_historical_average,

    avg(killed_count) over history_window
        as killed_count_historical_average,

    count(*) over history_window
        as historical_year_count

from {{ ref('int_traffic_accidents_weekly_county') }}

window history_window as (
    partition by
        county_name,
        iso_week
    order by iso_year
    rows between unbounded preceding and 1 preceding
)
