

with futures as (
    select * from {{ ref('stg_futures_prices') }}
),

mapping as (
    select * from {{ ref('stg_product_code_mapping') }}
),

fx as (
    select * from {{ ref('stg_fx_rates') }}
),

manifest as (
    select ingested_at_utc from {{ source('landing', 'ingestion_manifest') }}
),

joined as (
    select
        f.*,
        m.product,
        x.fx_rate_eur_usd
    from futures f
    left join mapping m
      on f.product_code = m.product_code
    left join fx x
      on f.contract_year  = x.contract_year
     and f.contract_month = x.contract_month
),

converted as (
    select
        *,
        case
            when unit_of_measure = '100KG' then price_local * 10
            else price_local
        end as price_local_mt
    from joined
)

select
    cast(c.trade_date as date)              as "Timestamp",
    c.market                                as "Market",
    c.product                               as "Product",
    'MT'                                    as "UnitOfMeasure",
    c.currency                              as "Currency",
    round(c.price_local_mt, 2)              as "PriceLocal",
    round(c.price_local_mt * c.fx_rate_eur_usd, 2) as "PriceUSDMT",
    c.period                                as "Period",
    c.contract_month                        as "Month",
    c.contract_year                         as "Year",
    m.ingested_at_utc                       as "IngestionTimestamp"
from converted c
cross join manifest m