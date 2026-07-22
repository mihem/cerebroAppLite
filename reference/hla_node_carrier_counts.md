# Per-node carrier / non-carrier / untyped counts for one allele

The counts behind \[hla_node_carrier_status()\]. A colour alone cannot
say whether a "Carrier" node rests on ten carriers or on one carrier and
nine untyped samples, so the UI shows these next to the label.

## Usage

``` r
hla_node_carrier_counts(samples_all, typing, samples, allele)
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

data.frame(n_carrier, n_noncarrier, n_untyped), one row per node.
