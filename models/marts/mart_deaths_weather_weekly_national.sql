select
    deaths.week_key,
    weeks.iso_year,
    weeks.iso_week,
    weeks.week_start_date,
    weeks.week_end_date,

    deaths.age_group_key,
    age_groups.age_group,
    age_groups.minimum_age,
    age_groups.maximum_age,

    deaths.sex_key,
    sexes.sex_code,
    sexes.sex,

    deaths.deaths_count,
    deaths.is_preliminary,

    death_history.deaths_count_historical_average,
    death_history.historical_year_count
        as deaths_historical_year_count,

    deaths.deaths_count
        - death_history.deaths_count_historical_average
        as deaths_difference_from_historical_average,

    weather.average_temperature,
    weather.maximum_temperature,
    weather.minimum_temperature,
    weather.total_precipitation,
    weather.average_wind_speed,
    weather.total_sunshine_duration,
    weather.hot_county_day_count,
    weather.cold_county_day_count,
    weather.observed_county_day_count,
    weather.observed_county_count,

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

from {{ ref('fct_deaths_weekly') }} as deaths

inner join {{ ref('dim_week') }} as weeks
    on deaths.week_key = weeks.week_key

inner join {{ ref('dim_age_group') }} as age_groups
    on deaths.age_group_key = age_groups.age_group_key

inner join {{ ref('dim_sex') }} as sexes
    on deaths.sex_key = sexes.sex_key

left join {{ ref('int_deaths_weekly_history') }} as death_history
    on deaths.week_key = death_history.week_key
    and age_groups.age_group = death_history.age_group
    and sexes.sex = death_history.sex

left join {{ ref('int_weather_weekly_national') }} as weather
    on deaths.week_key = weather.week_key

left join {{ ref('int_weather_weekly_national_history') }}
    as weather_history
    on deaths.week_key = weather_history.week_key
