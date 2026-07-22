# Build a descriptive analysis-unit by HLA-allele carrier matrix

Cells are 1 for carrier, 0 for locus-typed non-carrier and NA when that
locus is untyped. No statistical operation is applied to the matrix.

## Usage

``` r
hla_unit_allele_matrix(typing, samples)
```

## Arguments

- typing:

  Canonical HLA typing table.

- samples:

  In-scope immune-repertoire sample names.

## Value

data.frame with analysis-unit metadata followed by allele columns.
