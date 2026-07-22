# Node and edge tables for a motif graph

Turns the graph into the two tables an export needs. Vertex attributes
are carried through as-is; edges are emitted as CDR3 endpoint pairs so
the table is meaningful without the graph object.

## Usage

``` r
hla_graph_tables(graph)
```

## Arguments

- graph:

  A motif igraph from \[hla_build_motif_graph()\].

## Value

list(nodes = data.frame, edges = data.frame).
