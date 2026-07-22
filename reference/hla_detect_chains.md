# Detect receptor chains present in an immune-repertoire list

Scans the \`CTgene\` column of all samples for chain tokens.

## Usage

``` r
hla_detect_chains(data)
```

## Arguments

- data:

  Named list of scRepertoire-style data.frames (one per sample).

## Value

Character vector of detected chains, subset of TRA/TRB/TRG/TRD/
IGH/IGK/IGL, in that canonical order.
