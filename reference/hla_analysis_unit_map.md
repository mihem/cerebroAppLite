# Resolve sample or donor as the descriptive analysis unit

Donor-level collapse is used only when every in-scope sample has exactly
one non-empty donor ID. Otherwise all units remain samples; mixed
donor/sample counting is deliberately avoided.

## Usage

``` r
hla_analysis_unit_map(typing, samples)
```

## Arguments

- typing:

  Canonical HLA typing table.

- samples:

  In-scope immune-repertoire sample names.

## Value

data.frame(sample, analysis_unit, unit_type).
