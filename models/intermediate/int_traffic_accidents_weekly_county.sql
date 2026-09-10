with date_boundaries as (
    select
        date_trunc('week', min(accident_date))::date as first_week,
        date_trunc('week', max(accident_date))::date as last_week
    from {{ ref('stg_traffic_accidents') }}
),

weeks as (
    select
        week_start_date::date as week_start_date,
        extract(isoyear from week_start_date)::integer as iso_year,
        extract(week from week_start_date)::integer as iso_week
    from date_boundaries
    cross join lateral generate_series(
        first_week,
        last_week,
        interval '1 week'
    ) as week_start_date
),

week_county_structure as (
    select
        {{ generate_week_key('weeks.iso_year', 'weeks.iso_week') }}
            as week_key,
        weeks.iso_year,
        weeks.iso_week,
        counties.county_name
    from weeks
    cross join {{ ref('county_seed') }} as counties
),

accident_totals as (
    select
        week_key,
        iso_year,
        iso_week,
        county as county_name,
        count(*)::integer as accident_count,
        sum(injured_count)::integer as injured_count,
        sum(killed_count)::integer as killed_count
    from {{ ref('stg_traffic_accidents') }}
    group by
        week_key,
        iso_year,
        iso_week,
        county
)

select
    structure.week_key,
    structure.iso_year,
    structure.iso_week,
    structure.county_name,
    coalesce(accidents.accident_count, 0) as accident_count,
    coalesce(accidents.injured_count, 0) as injured_count,
    coalesce(accidents.killed_count, 0) as killed_count
from week_county_structure as structure
left join accident_totals as accidents
    on structure.week_key = accidents.week_key
    and structure.county_name = accidents.county_name