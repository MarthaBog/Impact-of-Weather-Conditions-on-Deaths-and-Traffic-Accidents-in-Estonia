with national_traffic as (
    select
        week_key,
        sum(accident_count) as accident_count,
        sum(injured_count) as injured_count,
        sum(killed_count) as killed_count
    from {{ ref('fct_traffic_weekly_county') }}
    group by week_key
),

national_deaths_weather as (
    select *
    from {{ ref('mart_deaths_weather_weekly_national') }}
    where sex = 'All'
      and age_group = 'All'
)

select
    deaths.week_key,
    deaths.iso_year,
    deaths.iso_week,
    deaths.week_start_date,
    deaths.week_end_date,

    deaths.deaths_count,
    deaths.deaths_difference_from_historical_average,

    traffic.accident_count,
    traffic.injured_count,
    traffic.killed_count,

    deaths.average_temperature,
    deaths.minimum_temperature,
    deaths.maximum_temperature,
    deaths.total_precipitation,
    deaths.total_sunshine_duration,
    deaths.average_wind_speed,

    deaths.average_temperature_difference_from_historical_average,
    deaths.precipitation_difference_from_historical_average,
    deaths.sunshine_difference_from_historical_average,
    deaths.wind_speed_difference_from_historical_average,

    deaths.weather_historical_year_count,
    deaths.weather_type

from national_deaths_weather as deaths

inner join national_traffic as traffic
    on deaths.week_key = traffic.week_key