# Per-node HLA carrier status for one allele (render-time, cache-safe)

Maps each motif node to the carrier status of the samples it was
observed in, for ONE allele. Deliberately a render-time helper: it takes
the node's sample set (\`samples_all\`, an allele-independent node
attribute) rather than being baked into the graph, so switching allele
re-colours without rebuilding the Hamming graph.

## Usage

``` r
hla_node_carrier_status(samples_all, typing, samples, allele)
```

## Arguments

- samples_all:

  Character vector, one entry per node: a comma-separated sorted sample
  list (the \`samples_all\` node attribute).

- typing:

  Canonical HLA typing table.

- samples:

  In-scope immune-repertoire sample names.

- allele:

  Canonical or normalizable HLA allele.

## Value

Character vector, one status per node.

## Details

A node aggregates observations from possibly several samples, so the
status summarises those samples' statuses. The labels describe the TYPED
samples only, because an untyped sample carries no information either
way: - "Carrier" at least one typed carrier and NO typed non-carrier; -
"Non-carrier" at least one typed non-carrier and NO typed carrier; -
"Mixed" both a typed carrier and a typed non-carrier; - "Untyped" no
carrying sample is typed at the allele's locus.

A "Carrier" node may therefore also have been seen in untyped samples:
it means "no evidence against", not "every sample is a carrier". Because
that distinction is invisible in a colour, callers must surface the
counts (see \[hla_node_carrier_counts()\]) rather than let the label
stand alone.

This is candidate co-occurrence, NOT restriction: a carrier's TCR is not
thereby restricted by that allele.
