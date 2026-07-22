# Sample of origin per node, collapsing multi-sample nodes to "Shared"

A node's \`sample\` metadata column is summarised as its MODE, which
paints a CDR3 seen in three samples with its dominant sample's colour
and hides the recurrence entirely. This reports the sample only when the
node was seen in exactly one; anything seen in more becomes
\[HLA_SHARED_LABEL\].

## Usage

``` r
hla_node_sample_origin(samples_all)
```

## Arguments

- samples_all:

  Character vector of comma-separated sorted sample lists (the
  \`samples_all\` node attribute).

## Value

Character vector: one sample name, "Shared", or NA when untracked.

## Details

Cross-sample sharing is not by itself evidence of an HLA association:
public CDR3s recur across unrelated donors. It is the observation an
association screen starts from, not its conclusion.
