select
    week_key,
    iso_year,
    iso_week,
    observation_date,
    station_code,
    station_name,

    max(
        case
            when metric_name = 'Air temperature (daily avg)'
            then metric_value
        end
    ) as average_temperature,

    max(
        case
            when metric_name = 'Air temperature (daily max)'
            then metric_value
        end
    ) as maximum_temperature,

    max(
        case
            when metric_name = 'Air temperature (daily min)'
            then metric_value
        end
    ) as minimum_temperature,

    max(
        case
            when metric_name = 'Precipitation (daily sum)'
            then metric_value
        end
    ) as precipitation,

    max(
        case
            when metric_name = 'Wind speed (daily avg)'
            then metric_value
        end
    ) as average_wind_speed,

    max(
        case
            when metric_name = 'Sunshine duration (daily sum)'
            then metric_value
        end
    ) as sunshine_duration

from {{ ref('stg_weather') }}

group by
    week_key,
    iso_year,
    iso_week,
    observation_date,
    station_code,
    station_name
