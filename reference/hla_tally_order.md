# Order a tally by descending count within each group

Stable (radix), and \[hla_group_tally()\] hands over runs already in
alphabetical order, so equal counts stay alphabetical. That is precisely
what \`sort(table(x), decreasing = TRUE)\` did: \`table()\` names its
counts by factor level (alphabetical) and R's sort keeps that order
among ties.

## Usage

``` r
hla_tally_order(t)
```

## Arguments

- t:

  A \[hla_group_tally()\] result.

## Value

The same list, reordered.

## Details

Getting this wrong is silent. Tallying in first-appearance order instead
flips roughly a fifth of tied modes, moving node colours and tooltips
with no error raised anywhere, so the order is a contract and is tested
as one.
