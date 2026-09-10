with typed as (
    select
        id as accident_id,
        source_row_number,
        accident_date,
        accident_time,
        trim(county) as county_raw,
        trim(municipality) as municipality,
        killed_count,
        injured_count
    from {{ source('raw', 'traffic_accidents') }}
    where accident_date is not null
),

enriched as (
    select
        accident_id,
        source_row_number,
        accident_date,
        accident_time,
        initcap(
            {{ normalize_county_name('county_raw') }}
        ) as county,
        municipality,
        extract(isoyear from accident_date)::integer as iso_year,
        extract(week from accident_date)::integer as iso_week,
        killed_count,
        injured_count
    from typed
)

select
    accident_id,
    source_row_number,
    accident_date,
    accident_time,
    county,
    municipality,
    iso_year,
    iso_week,
    {{ generate_week_key('iso_year', 'iso_week') }} as week_key,
    killed_count,
    injured_count
from enriched
where county is not null
  and county <> ''