select
    weeks.week_key,
    counties.county_key,
    weather.average_temperature,
    weather.maximum_temperature,
    weather.minimum_temperature,
    weather.total_precipitation,
    weather.average_wind_speed,
    weather.total_sunshine_duration,
    weather.hot_day_count,
    weather.cold_day_count,
    weather.observed_day_count,
    weather.maximum_station_count

from {{ ref('int_weather_weekly_county') }} as weather

inner join {{ ref('dim_week') }} as weeks
    on weather.week_key = weeks.week_key

inner join {{ ref('dim_county') }} as counties
    on weather.county_name = counties.county_name
