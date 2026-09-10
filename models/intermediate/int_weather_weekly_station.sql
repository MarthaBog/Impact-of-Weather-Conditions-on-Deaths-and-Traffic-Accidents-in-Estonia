select
    week_key,
    iso_year,
    iso_week,
    station_code,
    station_name,

    avg(average_temperature) as average_temperature,
    max(maximum_temperature) as maximum_temperature,
    min(minimum_temperature) as minimum_temperature,
    sum(precipitation) as total_precipitation,
    avg(average_wind_speed) as average_wind_speed,
    sum(sunshine_duration) as total_sunshine_duration,

    sum(
        case
            when maximum_temperature > 30 then 1
            else 0
        end
    )::integer as hot_day_count,

    sum(
        case
            when minimum_temperature < -10 then 1
            else 0
        end
    )::integer as cold_day_count,

    count(distinct observation_date)::integer as observed_day_count

from {{ ref('int_weather_daily_station') }}

group by
    week_key,
    iso_year,
    iso_week,
    station_code,
    station_name
