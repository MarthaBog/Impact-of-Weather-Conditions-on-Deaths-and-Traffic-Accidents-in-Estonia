select
    weeks.week_key,
    counties.county_key,
    traffic.accident_count,
    traffic.injured_count,
    traffic.killed_count

from {{ ref('int_traffic_accidents_weekly_county') }} as traffic

inner join {{ ref('dim_week') }} as weeks
    on traffic.week_key = weeks.week_key

inner join {{ ref('dim_county') }} as counties
    on traffic.county_name = counties.county_name