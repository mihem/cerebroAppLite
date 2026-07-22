# Restrict segments to the cells that could bear on one HLA allele

The per-allele view of an HLA screen. Two filters, both necessary: 1.
the cell's sample must CARRY the allele (a non-carrier's receptor cannot
be restricted by an allele the donor does not have); 2. the cell's
lineage-derived MHC class must MATCH the allele's class — a class II
allele cannot restrict a CD8 cell's receptor, and vice versa. The
Hamming graph is then rebuilt on the subset, so an edge never joins a
carrier's CDR3 to a non-carrier's. That is the difference from
re-colouring a global graph, which leaves such edges in place.

## Usage

``` r
hla_scope_segments_by_allele(seg, typing, allele, context_col = "mhc_context")
```

## Arguments

- seg:

  Parsed segments; needs a \`sample\` column.

- typing:

  Canonical HLA typing table.

- allele:

  Canonical allele, e.g. \`"HLA-A\*02:01"\`.

- context_col:

  Name of the per-cell MHC-context column ("Class I"/"Class
  II"/"Unknown"), or NULL to skip class matching.

## Value

A subset of \`seg\` (possibly zero rows), or NULL when unusable.

## Details

Cells whose context is "Unknown" are dropped by the class filter rather
than assumed into a class. When the data set has no context column at
all (a bulk repertoire has no lineage), only the carrier filter applies
— a weaker scope, which the caller must surface rather than present as
class-matched.

This is a SUBSET, not a test, and it deliberately removes the comparison
group: inside it every donor is a carrier, so "this motif recurs across
donors" cannot be told apart from an ordinary public TCR. The carrier
colouring on the unscoped graph is what supplies that contrast.

Note also that a carrier has up to six class I alleles; scoping to one
of them keeps ALL of that donor's class-I-restricted receptors,
including those restricted by the other five. The scope is candidate
co-occurrence, never confirmed restriction.
