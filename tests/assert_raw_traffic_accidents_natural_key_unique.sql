select
    source_row_number,
    count(*) as row_count
from {{ source('raw', 'traffic_accidents') }}
group by source_row_number
having count(*) > 1