# Scope segments to one Class I x Class II allele pair

The pair view asks a different question from the single-allele scope:
not "what do carriers of X look like" but "within the donors who could
present on X (class I) or Y (class II), which CDR3s turn up on each
side, and which turn up on BOTH".

## Usage

``` r
hla_scope_segments_by_allele_pair(
  seg,
  typing,
  allele_i,
  allele_ii,
  context_col = "mhc_context"
)
```

## Arguments

- seg:

  Parsed segments (needs \`sample\` and the lineage context column).

- typing:

  Canonical HLA typing table.

- allele_i:

  A Class I allele.

- allele_ii:

  A Class II allele.

- context_col:

  Per-cell MHC-context column. Required: NULL returns NULL.

## Value

\`seg\` subset to the pair, plus a \`pair_allele\` column; NULL when the
pair is not analysable (no lineage, same class, unrecognisable alleles).

## Details

Every kept cell is assigned the ONE allele its own lineage could
actually use AND its donor actually carries: \* a Class I (CD8) cell of
a donor carrying \`allele_i\` -\> allele_i \* a Class II (CD4/Treg) cell
of a donor carrying \`allele_ii\` -\> allele_ii \* anything else is
dropped, including a Class I cell from a donor who carries only
\`allele_ii\`: that cell has no candidate in this pair, and keeping it
would put a receptor under an allele its donor does not have.

Unknown-lineage cells are always dropped: the assignment IS the lineage,
so a cell with no lineage cannot claim either side.

As with every scope on this page, this is co-occurrence, never
restriction: a CDR3 sitting under \`allele_i\` only means it was seen in
a CD8 cell of a donor who carries it.
