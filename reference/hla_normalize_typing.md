# Normalize any accepted HLA input into the canonical long table

Accepts: \* a canonical/near-canonical long data.frame (has \`sample\` +
\`allele\`); \* a wide data.frame (\`sample\` + \`HLA-A_1\`,
\`HLA-A_2\`, ... columns); \* a named list (\`sample -\>
c("HLA-A\*02:01", ...)\`).

## Usage

``` r
hla_normalize_typing(
  x,
  source_type = "unknown",
  typing_method = NA_character_,
  source_reference = NA_character_
)
```

## Arguments

- x:

  One of the accepted inputs.

- source_type:

  One of \[HLA_SOURCE_TYPES\]; default "unknown".

- typing_method, source_reference:

  Optional provenance strings.

## Value

A canonical long data.frame with a "qc" attribute (warnings df).

## Details

Output columns are exactly \[HLA_TYPING_COLUMNS\]. \`copy\` (1/2) is
assigned per (sample, locus) in input order. Unrecognisable alleles are
dropped from the table but reported via attribute "qc" (a data.frame of
warnings). Provenance defaults to \`source_type = "unknown"\` with a
blocking warning when absent – allele format is never used to guess
\`genotyped\`.
