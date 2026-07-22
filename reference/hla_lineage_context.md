# Map a cell-type label to a lineage-derived MHC class context

CD8 lineage -\> "Class I", CD4 / Treg -\> "Class II", everything else
-\> "Unknown" (never guessed). This is explicitly a lineage-derived
CONTEXT, not a confirmed restriction; a coarse "T cells" label yields
"Unknown".

## Usage

``` r
hla_lineage_context(cell_type)
```

## Arguments

- cell_type:

  A character vector of cell-type labels.

## Value

A character vector of "Class I" / "Class II" / "Unknown".
