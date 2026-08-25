with source as (

    select * from {{ source('landing', 'product_code_mapping') }}

),

renamed as (

    select
        RIC     as product_code,
        Product as product
    from source

)

select * from renamed