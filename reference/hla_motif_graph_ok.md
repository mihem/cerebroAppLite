# Is a motif-graph result a usable igraph?

\[hla_build_motif_graph()\] returns NULL (nothing to draw), an NA
carrying a "guard" attribute (a size guard tripped), or an igraph. This
is the single predicate for "we have a drawable graph".

## Usage

``` r
hla_motif_graph_ok(g)
```

## Arguments

- g:

  A return value of \[hla_build_motif_graph()\].

## Value

TRUE only when \`g\` is an igraph with at least one vertex.
