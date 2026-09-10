select
    week_key,
    iso_year,
    iso_week,
    county_name,

    avg(average_temperature) over history_window
        as average_temperature_historical_average,

    avg(maximum_temperature) over history_window
        as maximum_temperature_historical_average,

    avg(minimum_temperature) over history_window
        as minimum_temperature_historical_average,

    avg(total_precipitation) over history_window
        as total_precipitation_historical_average,

    avg(average_wind_speed) over history_window
        as average_wind_speed_historical_average,

    avg(total_sunshine_duration) over history_window
        as total_sunshine_duration_historical_average,

    avg(hot_day_count) over history_window
        as hot_day_count_historical_average,

    avg(cold_day_count) over history_window
        as cold_day_count_historical_average,

    count(*) over history_window
        as historical_year_count

from {{ ref('int_weather_weekly_county') }}

window history_window as (
    partition by
        county_name,
        iso_week
    order by iso_year
    rows between unbounded preceding and 1 preceding
)