with national_traffic as (

    select
        week_key,

        sum(accident_count) as accident_count,
        sum(injured_count) as injured_count,
        sum(killed_count) as killed_count

    from {{ ref('fct_traffic_weekly_county') }}

    group by week_key
),

deaths_weather as (

    select *
    from {{ ref('mart_deaths_weather_weekly_national') }}

)

select

    deaths.week_key,
    deaths.iso_year,
    deaths.iso_week,
    deaths.week_start_date,
    deaths.week_end_date,

    deaths.iso_year::text
        || '-'
        || lpad(deaths.iso_week::text, 2, '0')
        as year_week,


    extract(
        month from deaths.week_start_date + interval '3 days'
    )::integer as month_number,

    case extract(month from deaths.week_start_date + interval '3 days')
    when 1 then E'\u200BJaanuar'
    when 2 then E'\u200B\u200BVeebruar'
    when 3 then E'\u200B\u200B\u200BMärts'
    when 4 then E'\u200B\u200B\u200B\u200BAprill'
    when 5 then E'\u200B\u200B\u200B\u200B\u200BMai'
    when 6 then E'\u200B\u200B\u200B\u200B\u200B\u200BJuuni'
    when 7 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200BJuuli'
    when 8 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200BAugust'
    when 9 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200BSeptember'
    when 10 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200BOktoober'
    when 11 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200BNovember'
    when 12 then E'\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200B\u200BDetsember'
end as month_name_sorted,

    case
        when extract(
            month from deaths.week_start_date + interval '3 days'
        ) in (12, 1, 2)
            then 'Talv'

        when extract(
            month from deaths.week_start_date + interval '3 days'
        ) in (3, 4, 5)
            then 'Kevad'

        when extract(
            month from deaths.week_start_date + interval '3 days'
        ) in (6, 7, 8)
            then 'Suvi'

        else 'Sügis'
    end as season,

    extract(
        year from deaths.week_start_date + interval '3 days'
    )::integer::text
        || ' '
        ||
        case extract(
            month from deaths.week_start_date + interval '3 days'
        )
            when 1 then 'Jaanuar'
            when 2 then 'Veebruar'
            when 3 then 'Märts'
            when 4 then 'Aprill'
            when 5 then 'Mai'
            when 6 then 'Juuni'
            when 7 then 'Juuli'
            when 8 then 'August'
            when 9 then 'September'
            when 10 then 'Oktoober'
            when 11 then 'November'
            when 12 then 'Detsember'
        end as year_month,



    deaths.sex,
    deaths.age_group,



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

    deaths.weather_type as weather_type_raw,

    case
    when deaths.weather_type = 'Typical'
        then 'Tavapärane'
    when deaths.weather_type = 'Unusual'
        then 'Ebatavaline'
    else null
end as weather_type

from deaths_weather as deaths

inner join national_traffic as traffic
    on deaths.week_key = traffic.week_key