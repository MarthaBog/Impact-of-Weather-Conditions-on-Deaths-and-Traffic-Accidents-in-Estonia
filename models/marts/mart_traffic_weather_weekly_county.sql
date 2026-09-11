select
    traffic.week_key,
    weeks.iso_year,
    weeks.iso_week,
    weeks.week_start_date,
    weeks.week_end_date,

    traffic.county_key,
    counties.county_name,
    counties.county_code,

    traffic.accident_count,
    traffic.injured_count,
    traffic.killed_count,

    traffic_history.accident_count_historical_average,

    traffic.accident_count
        - traffic_history.accident_count_historical_average
        as accident_count_difference_from_historical_average,

    traffic_history.injured_count_historical_average,

    traffic.injured_count
        - traffic_history.injured_count_historical_average
        as injured_count_difference_from_historical_average,

    traffic_history.killed_count_historical_average,

    traffic.killed_count
        - traffic_history.killed_count_historical_average
        as killed_count_difference_from_historical_average,

    traffic_history.historical_year_count
        as traffic_historical_year_count,

    weather.average_temperature,
    weather.maximum_temperature,
    weather.minimum_temperature,
    weather.total_precipitation,
    weather.average_wind_speed,
    weather.total_sunshine_duration,
    weather.hot_day_count,
    weather.cold_day_count,

    coalesce(weather.observed_day_count, 0)
        as observed_day_count,

    weather.maximum_station_count,

    case
        when weather.average_temperature is not null then true
        else false
    end as has_weather_data,

    case
        when weather.observed_day_count = 7 then true
        else false
    end as has_complete_weather_week,

    weather_history.average_temperature_historical_average,

    weather.average_temperature
        - weather_history.average_temperature_historical_average
        as average_temperature_difference_from_historical_average,

    weather_history.maximum_temperature_historical_average,

    weather.maximum_temperature
        - weather_history.maximum_temperature_historical_average
        as maximum_temperature_difference_from_historical_average,

    weather_history.minimum_temperature_historical_average,

    weather.minimum_temperature
        - weather_history.minimum_temperature_historical_average
        as minimum_temperature_difference_from_historical_average,

    weather_history.total_precipitation_historical_average,

    weather.total_precipitation
        - weather_history.total_precipitation_historical_average
        as precipitation_difference_from_historical_average,

    weather_history.average_wind_speed_historical_average,

    weather.average_wind_speed
        - weather_history.average_wind_speed_historical_average
        as wind_speed_difference_from_historical_average,

    weather_history.total_sunshine_duration_historical_average,

    weather.total_sunshine_duration
        - weather_history.total_sunshine_duration_historical_average
        as sunshine_difference_from_historical_average,

        weather_history.historical_year_count
        as weather_historical_year_count,

    case
        when weather_history.historical_year_count < 3
            or weather.average_temperature is null
            or weather_history.average_temperature_historical_stddev is null
            or weather_history.total_precipitation_historical_stddev is null
            or weather_history.total_sunshine_duration_historical_stddev is null
            or weather_history.average_wind_speed_historical_stddev is null
        then 'Insufficient history'

        when abs(
            weather.average_temperature
            - weather_history.average_temperature_historical_average
        ) > 2 * weather_history.average_temperature_historical_stddev
        then 'Unusual'

        when abs(
            weather.total_precipitation
            - weather_history.total_precipitation_historical_average
        ) > 2 * weather_history.total_precipitation_historical_stddev
        then 'Unusual'

        when abs(
            weather.total_sunshine_duration
            - weather_history.total_sunshine_duration_historical_average
        ) > 2 * weather_history.total_sunshine_duration_historical_stddev
        then 'Unusual'

        when abs(
            weather.average_wind_speed
            - weather_history.average_wind_speed_historical_average
        ) > 2 * weather_history.average_wind_speed_historical_stddev
        then 'Unusual'

        else 'Typical'
    end as weather_type

from {{ ref('fct_traffic_weekly_county') }} as traffic

inner join {{ ref('dim_week') }} as weeks
    on traffic.week_key = weeks.week_key

inner join {{ ref('dim_county') }} as counties
    on traffic.county_key = counties.county_key

left join {{ ref('int_traffic_accidents_weekly_county_history') }}
    as traffic_history
    on traffic.week_key = traffic_history.week_key
    and counties.county_name = traffic_history.county_name

left join {{ ref('fct_weather_weekly_county') }} as weather
    on traffic.week_key = weather.week_key
    and traffic.county_key = weather.county_key

left join {{ ref('int_weather_weekly_county_history') }}
    as weather_history
    on traffic.week_key = weather_history.week_key
    and counties.county_name = weather_history.county_name