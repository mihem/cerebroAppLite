# Per-motif summary table

One row per Hamming-1 connected component: size, consensus and max
mismatch. \`max_mismatch\` is included because a component's membership
is transitive, so its members are not all within distance 1 of each
other. It is the largest pairwise Hamming distance in the component —
NOT the graph's diameter, which counts hops and is larger.

## Usage

``` r
hla_motif_summary(graph)
```

## Arguments

- graph:

  A motif igraph from \[hla_build_motif_graph()\].

## Value

data.frame(motif_group, n_cdr3, consensus, max_mismatch).
