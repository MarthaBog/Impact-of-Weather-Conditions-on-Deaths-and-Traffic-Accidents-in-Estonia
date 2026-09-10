select
    indicator,
    iso_week_label,
    observation_year,
    sex,
    age_group,
    count(*) as row_count
from {{ source('raw', 'deaths') }}
group by
    indicator,
    iso_week_label,
    observation_year,
    sex,
    age_group
having count(*) > 1
