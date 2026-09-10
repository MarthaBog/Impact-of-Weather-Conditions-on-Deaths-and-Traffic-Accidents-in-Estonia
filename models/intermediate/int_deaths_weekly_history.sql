select
    week_key,
    iso_year,
    iso_week,
    age_group,
    sex,

    avg(deaths_count) over history_window
        as deaths_count_historical_average,

    count(deaths_count) over history_window
        as historical_year_count

from {{ ref('stg_deaths') }}

window history_window as (
    partition by
        age_group,
        sex,
        iso_week
    order by iso_year
    rows between unbounded preceding and 1 preceding
)
