select
    deaths.week_key,
    age_groups.age_group_key,
    sexes.sex_key,
    deaths.deaths_count::integer as deaths_count,
    deaths.is_preliminary

from {{ ref('stg_deaths') }} as deaths

inner join {{ ref('dim_week') }} as weeks
    on deaths.week_key = weeks.week_key

inner join {{ ref('dim_age_group') }} as age_groups
    on deaths.age_group = age_groups.age_group

inner join {{ ref('dim_sex') }} as sexes
    on deaths.sex = sexes.sex
