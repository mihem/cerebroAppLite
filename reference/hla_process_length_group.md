# Cluster equal-length CDR3s within one length bin at Hamming distance 1

All rows of \`df\` must share one CDR3 length (caller guarantees this).

## Usage

``` r
hla_process_length_group(df)
```

## Arguments

- df:

  data.frame with a \`cdr3\` column (all equal length).

## Value

list(df = df + motif columns, edges = Hamming==1 pairs or NULL).
