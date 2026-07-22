# Summarise a node's per-cell candidate alleles into one pair class

In a Class I x Class II pair scope every cell carries the allele its
lineage would present on (\[hla_scope_segments_by_allele_pair\]). A CDR3
node pools cells, so it can span both compartments: that is the
observation the pair network exists to show, and it must not be averaged
away – taking the modal allele would silently report such a node as
whichever compartment happened to contribute more cells.

## Usage

``` r
hla_pair_class_summary(x)
```

## Arguments

- x:

  Per-cell candidate alleles (NA where none applies).

## Value

The single allele when all cells agree, \[HLA_PAIR_MIXED_LABEL\] when
both appear, NA when there is nothing to summarise.
