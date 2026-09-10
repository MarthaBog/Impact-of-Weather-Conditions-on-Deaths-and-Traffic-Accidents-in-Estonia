with sexes as (
    select distinct sex
    from {{ ref('stg_deaths') }}
)

select
    row_number() over (
        order by
            case sex
                when 'All' then 1
                when 'Male' then 2
                when 'Female' then 3
                else 99
            end
    ) as sex_key,

    case
        when sex = 'All' then 'all'
        when sex = 'Male' then 'male'
        when sex = 'Female' then 'female'
        else lower(sex)
    end as sex_code,

    sex

from sexes
