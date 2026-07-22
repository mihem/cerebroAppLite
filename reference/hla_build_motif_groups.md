# Build motif groups over all length bins (optionally within V gene)

Splits unique CDR3s into equal-length bins (Hamming only compares equal
lengths), clusters each, and stitches results back together.

## Usage

``` r
hla_build_motif_groups(df, by_v = FALSE)
```

## Arguments

- df:

  data.frame with \`cdr3\` (+ \`v_gene\` when \`by_v\`); one row per
  unique node key already aggregated by the caller.

- by_v:

  When TRUE, split by (V gene, length) and prefix motif ids by V.

## Value

list(motif_df = per-CDR3 assignment, edges = Hamming==1 pairs or NULL)
