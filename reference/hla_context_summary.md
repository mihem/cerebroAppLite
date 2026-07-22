# Summarise a distribution of MHC-context labels to one node summary

A CDR3 node carries cells of possibly mixed lineage. Collapse the
per-cell contexts to a single node summary: a single non-Unknown class
stays that class; both Class I and Class II present -\> "Mixed"; only
Unknown -\> "Unknown".

## Usage

``` r
hla_context_summary(contexts)
```

## Arguments

- contexts:

  A character vector of per-cell context labels.

## Value

One of "Class I" / "Class II" / "Mixed" / "Unknown".
