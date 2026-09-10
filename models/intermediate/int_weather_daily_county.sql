select
    weather.week_key,
    weather.iso_year,
    weather.iso_week,
    weather.observation_date,
    mapping.county_name,

    avg(weather.average_temperature) as average_temperature,
    avg(weather.maximum_temperature) as maximum_temperature,
    avg(weather.minimum_temperature) as minimum_temperature,
    avg(weather.precipitation) as precipitation,
    avg(weather.average_wind_speed) as average_wind_speed,
    avg(weather.sunshine_duration) as sunshine_duration,

    count(distinct weather.station_code)::integer
        as observed_station_count

from {{ ref('int_weather_daily_station') }} as weather

inner join {{ ref('station_county_map') }} as mapping
    on weather.station_code = mapping.station_code

group by
    weather.week_key,
    weather.iso_year,
    weather.iso_week,
    weather.observation_date,
    mapping.county_name
