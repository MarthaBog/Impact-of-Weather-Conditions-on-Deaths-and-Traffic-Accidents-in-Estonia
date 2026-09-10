select
    weeks.week_key,
    stations.station_key,
    weather.average_temperature,
    weather.maximum_temperature,
    weather.minimum_temperature,
    weather.total_precipitation,
    weather.average_wind_speed,
    weather.total_sunshine_duration,
    weather.hot_day_count,
    weather.cold_day_count,
    weather.observed_day_count

from {{ ref('int_weather_weekly_station') }} as weather

inner join {{ ref('dim_week') }} as weeks
    on weather.week_key = weeks.week_key

inner join {{ ref('dim_weather_station') }} as stations
    on weather.station_code = stations.station_code
