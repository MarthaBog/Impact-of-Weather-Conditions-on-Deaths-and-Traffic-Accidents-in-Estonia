select
    week_key,
    iso_year,
    iso_week,

    avg(average_temperature) as average_temperature,
    avg(maximum_temperature) as maximum_temperature,
    avg(minimum_temperature) as minimum_temperature,
    avg(total_precipitation) as total_precipitation,
    avg(average_wind_speed) as average_wind_speed,
    avg(total_sunshine_duration) as total_sunshine_duration,

    sum(hot_day_count)::integer as hot_county_day_count,
    sum(cold_day_count)::integer as cold_county_day_count,
    sum(observed_day_count)::integer as observed_county_day_count,
    count(distinct county_name)::integer as observed_county_count

from {{ ref('int_weather_weekly_county') }}

group by
    week_key,
    iso_year,
    iso_week
