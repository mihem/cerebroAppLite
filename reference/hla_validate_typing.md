# Validate and clean an already-canonical HLA typing table

\[hla_is_typing_table()\] only checks that the columns exist, so a table
can pass it while still carrying an unrecognisable allele, a locus that
contradicts its allele, a copy value outside 1/2, or an invalid
provenance. \`addHLATyping()\` used to store such a table verbatim. This
re-applies the per-value rules \[hla_normalize_typing()\] enforces on
raw input – WITHOUT clobbering the table's own provenance columns, which
is why it is separate from normalization (normalization stamps a single
source_type from its argument and would overwrite genuine per-row
provenance).

## Usage

``` r
hla_validate_typing(typing)
```

## Arguments

- typing:

  A data.frame with the canonical columns.

## Value

A cleaned canonical long table (possibly zero-row).

## Details

Rows with an unrecognisable allele are dropped; locus and resolution are
re-derived from the allele so they cannot contradict it; a copy outside
1/2 becomes NA; a source_type outside \[HLA_SOURCE_TYPES\] becomes
"unknown".
