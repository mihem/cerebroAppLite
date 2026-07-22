# Samples that definitely carry an allele, resolution-aware

Unlike \[hla_carrier_index()\], which keys on the exact allele string,
this resolves typing recorded at a finer resolution than the query (a
donor typed \`A\*02:01\` does carry \`A\*02\`). Donors whose typing is
too coarse to decide are NOT returned: they are unknown, not carriers.

## Usage

``` r
hla_carriers_of(typing, allele)
```

## Arguments

- typing:

  Canonical HLA typing table.

- allele:

  Canonical allele.

## Value

Character vector of sample names.
