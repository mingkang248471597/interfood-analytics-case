with source as (

    select * from {{ source('landing', 'fx_rates') }}

),

eur_usd as (

    select
        cast(Timestamp as date)   as curve_date,
        cast(Year as integer)     as contract_year,
        cast(Month as integer)    as contract_month,
        FxRate                    as fx_rate_eur_usd,
        Imputed                   as imputation_flag
    from source
    where FromCurrencyCode = 'EUR'
      and ToCurrencyCode = 'USD'

),

latest_curve as (

    select *
    from eur_usd
    where curve_date = (select max(curve_date) from eur_usd)

)

select * from latest_curve