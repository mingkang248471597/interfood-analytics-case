with envelope as (

    select * from {{ source('landing', 'futures_prices') }}

),

flattened as (

    -- the file is an OData envelope; the records live in the Contents array
    select unnest(Contents, recursive := true)
    from envelope

),

valid_rows as (

    -- two distinct exclusions:
    --   "Error" is not null      -> extraction error stubs (4 rows)
    --   "Trade Date" is null     -> contracts expired before the sample week (4 rows)
    select *
    from flattened
    where "Error" is null
      and "Trade Date" is not null

),

renamed as (

    select
        cast("Trade Date" as date)                          as trade_date,
        "Exchange Code"                                     as market,
        "Product Code"                                      as product_code,
        case "Lot Units"
            when 'TONNE' then 'MT'
            when 'KG100' then '100KG'
            else "Lot Units"
        end                                                 as unit_of_measure,
        "Currency Code"                                     as currency,
        cast("Universal Close Price" as double)             as price_local,
        cast("Expiration Date" as date)                     as period,
        month(strptime("Contract Month and Year", '%b%Y'))  as contract_month,
        year(strptime("Contract Month and Year", '%b%Y'))   as contract_year
    from valid_rows

)

select * from renamed