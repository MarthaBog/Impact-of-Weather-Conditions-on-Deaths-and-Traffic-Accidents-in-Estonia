with age_groups as (
    select distinct age_group
    from {{ ref('stg_deaths') }}
)

select
    row_number() over (
        order by
            case age_group
                when 'All' then 1
                when '0-64' then 2
                when '65-79' then 3
                when '80 and older' then 4
                else 99
            end
    ) as age_group_key,

    age_group,

    case
        when age_group = '0-64' then 0
        when age_group = '65-79' then 65
        when age_group = '80 and older' then 80
        else null
    end as minimum_age,

    case
        when age_group = '0-64' then 64
        when age_group = '65-79' then 79
        else null
    end as maximum_age

from age_groups
