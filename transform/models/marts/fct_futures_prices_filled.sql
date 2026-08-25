{{ config(
    post_hook = "{% if target.name == 'prod' %} copy (select * from {{ this }}) to '../output/futures_prices.csv' (header, delimiter ',') {% endif %}"
) }}

with base as (
    select * from {{ ref('fct_futures_prices') }}
),

last_day as (
    select max("Timestamp") as last_ts from base
),

next_trade_day as (
    select
        cast(
            case dayofweek(last_ts)
                when 5 then last_ts + interval 3 day
                when 6 then last_ts + interval 2 day
                else        last_ts + interval 1 day
            end
        as date) as next_ts
    from last_day
),

filled as (
    select
        n.next_ts               as "Timestamp",
        b."Market",
        b."Product",
        b."UnitOfMeasure",
        b."Currency",
        b."PriceLocal",
        b."PriceUSDMT",
        b."Period",
        b."Month",
        b."Year",
        b."IngestionTimestamp"
    from base b
    cross join next_trade_day n
    where b."Timestamp" = (select last_ts from last_day)
)

select * from base
union all
select * from filled