# Generate a stable distinct colour for every categorical level

The first ten levels use the page's established palette. Larger sets
switch to an HCL palette rather than cycling colours and making
different categories visually indistinguishable.

## Usage

``` r
hla_distinct_colors(levels)
```

## Arguments

- levels:

  Character vector of categorical levels in display order.

## Value

Named character vector \`level -\> colour\`.
