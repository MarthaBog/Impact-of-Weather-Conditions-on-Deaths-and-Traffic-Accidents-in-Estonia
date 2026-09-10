with filtered as (
    select
        observation_year,
        iso_week_label::integer as iso_week,
        sex,
        age_group,
        deaths_count
    from {{ source('raw', 'deaths') }}
    where indicator = 'Surmade arv'
      and deaths_count is not null
      and iso_week_label ~ '^[0-9]+$'
),

translated as (
    select
        observation_year as iso_year,
        iso_week,
        case
            when sex = 'Mehed ja naised' then 'All'
            when sex = 'Mehed' then 'Male'
            when sex = 'Naised' then 'Female'
            else sex
        end as sex,
        case
            when age_group = 'Vanuserühmad kokku' then 'All'
            when age_group = '80 ja vanemad' then '80 and older'
            else age_group
        end as age_group,
        deaths_count,
        case
            when observation_year >= 2025 then true
            else false
        end as is_preliminary
    from filtered
)

select
    {{ generate_week_key('iso_year', 'iso_week') }} as week_key,
    iso_year,
    iso_week,
    sex,
    age_group,
    deaths_count,
    is_preliminary
from translated
where iso_week between 1 and 53
