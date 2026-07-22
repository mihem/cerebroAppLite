# Normalize one raw allele token to canonical \`HLA-\<locus\>\*\<fields\>\`

Accepts \`A\*02:01\`, \`HLA-A\*02:01\`, or a bare \`02:01\` when
\`locus\` is supplied. \`NNNN\` / empty / \`NA\` become NA (missing).
Field resolution is preserved (never auto-padded). Returns NA for
anything unrecognisable; the caller logs it as a QC warning rather than
silently dropping it.

## Usage

``` r
hla_normalize_allele(x, locus = NULL)
```

## Arguments

- x:

  A raw allele token.

- locus:

  Optional locus (e.g. "HLA-A") for bare \`02:01\` inputs.

## Value

A canonical allele string, or NA_character\_.
