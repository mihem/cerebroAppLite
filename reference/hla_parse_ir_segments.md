# Parse V / J / CDR3 for one chain out of scRepertoire CT\* columns

scRepertoire packs every chain of a cell into single underscore-joined
strings (\`CTgene\`, \`CTaa\`); this returns one row per cell that HAS
the requested chain, with parsed \`v_gene\` / \`j_gene\` / \`cdr3\` plus
a combined \`clone_vjc = "v;j;cdr3"\` clone identity and every metadata
column already joined onto the IR data.

## Usage

``` r
hla_parse_ir_segments(data, chain)
```

## Arguments

- data:

  Named list of IR data.frames (with metadata joined by barcode).

- chain:

  Chain prefix, e.g. "TRB" / "TRA".

## Value

A data.frame with one row per cell carrying \`chain\`, or NULL.
