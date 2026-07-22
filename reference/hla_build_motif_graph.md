# Build the CDR3 Hamming-1 motif igraph from parsed segments

Parses nothing itself: takes already-parsed segments, aggregates to
unique CDR3 nodes, clusters by Hamming distance 1 (optionally within V
gene), and returns an igraph whose vertices carry \`cdr3\` /
\`motif\_\*\` attributes + per- node metadata distributions +
\`clone_count\`.

## Usage

``` r
hla_build_motif_graph(
  seg,
  by_v = FALSE,
  min_nodes = 2L,
  show_isolated = FALSE,
  meta_cols = character(0),
  context_col = NULL,
  context_summary = hla_context_summary
)
```

## Arguments

- seg:

  Output of \[hla_parse_ir_segments()\].

- by_v:

  Split clustering within V gene.

- min_nodes:

  Keep connected components of size \>= \`min_nodes\`. Default 2.

- show_isolated:

  When TRUE, also keep isolated (degree-0) CDR3s as points.

- meta_cols:

  Metadata columns to carry as node distributions.

- context_col:

  Optional per-cell context column; the node gets a \`context_summary\`
  value rather than a mode.

- context_summary:

  Collapse function for \`context_col\`; see
  \[hla_aggregate_cdr3_nodes()\].

## Value

An igraph object (with a per-node \`cluster\` attribute and a
\`total_cells\` graph attribute) or NULL. Attaches attr "guard" with a
message when a size guard tripped (graph is NULL in that case).
