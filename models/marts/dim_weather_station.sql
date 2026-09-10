select
    row_number() over (
        order by mapping.station_code
    ) as station_key,

    mapping.station_code,
    mapping.station_name,
    county.county_key

from {{ ref('station_county_map') }} as mapping

inner join {{ ref('dim_county') }} as county
    on mapping.county_name = county.county_name
