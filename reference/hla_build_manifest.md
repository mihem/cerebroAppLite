# Build the export manifest for one HLA & TCR Motifs view

Records the parameters and caveats a reader needs to interpret (or
recompute) the exported tables. Pure: takes values, returns a
data.frame.

## Usage

``` r
hla_build_manifest(
  dataset,
  chain,
  input_channel,
  hla_source_type,
  unit_type,
  observation_unit,
  n_units,
  n_nodes,
  n_edges,
  n_motifs,
  min_nodes,
  split_by_v,
  show_isolated,
  allele = NA_character_,
  scope = NA_character_,
  allele_i = NA_character_,
  allele_ii = NA_character_,
  lineage_column = NA_character_,
  tcr_selection = NA_character_,
  qc_warnings = character(0),
  app_version = NA_character_
)
```

## Arguments

- dataset:

  Name of the loaded data set.

- chain:

  Receptor chain analysed.

- input_channel:

  Where the active HLA came from ("stored .crb" / "session upload" /
  "none").

- hla_source_type:

  Provenance of the genotype (genotyped / imputed / synthetic /
  unknown).

- unit_type:

  Statistical unit actually used ("donor" / "sample").

- observation_unit:

  What one row of the data set is ("cell" / "analysis unit").

- n_units, n_nodes, n_edges, n_motifs:

  Counts describing the exported view.

- min_nodes, split_by_v, show_isolated:

  Motif build parameters.

- allele:

  Allele the view was coloured / summarised by, if any.

- scope:

  Network scope in effect ("all" / "allele" / "pair"); with "all" the
  whole graph is shown and the allele only re-colours it, so the scope
  is needed to know whether the exported nodes are a subset.

- allele_i, allele_ii:

  The two alleles when \`scope\` is a Class I x II pair, otherwise NA.

- lineage_column:

  Metadata column the CD4/CD8 lineage was read from, if any; it
  determines the class filter that allele / pair scope applied.

- tcr_selection:

  Declared receptor-selection provenance, if any.

- qc_warnings:

  Character vector of QC warnings, if any.

- app_version:

  Package version string.

## Value

A two-column data.frame(field, value).
