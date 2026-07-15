##----------------------------------------------------------------------------##
## HLA & TCR Motifs — core function shim
##
## The pure motif / HLA-typing core lives in the package (R/hla_motif_core.R,
## R/hla_typing.R) so it is installed and unit-tested. The Shiny app, however,
## runs with the package LOADED but NOT ATTACHED (app.R does not call
## library(cerebroAppLite)); a bare call to a non-exported package function
## therefore fails at runtime (the spatial-helpers namespace trap).
##
## This file is sourced with local = TRUE into the module server scope, so the
## assignments below land in that scope and every other module file can call the
## core functions by bare name. We use getFromNamespace() — an explicit,
## documented API — NOT the ::: operator that the project bans in runtime code.
##----------------------------------------------------------------------------##

## Only bind when the namespace is loaded (the normal app path). Under
## devtools::load_all the functions are already in scope, so this is a no-op.
if ("cerebroAppLite" %in% loadedNamespaces()) {
  for (.hla_fn in c(
    "hla_detect_chains",
    "hla_parse_ir_segments",
    "hla_make_consensus",
    "hla_motif_variable_aa",
    "hla_build_motif_graph",
    "hla_motif_graph_ok",
    "HLA_MOTIF_MAX_RENDER",
    "hla_normalize_typing",
    "hla_normalize_allele",
    "hla_allele_resolution",
    "hla_allele_locus",
    "hla_locus_class",
    "hla_is_typing_table",
    "hla_carrier_index",
    "hla_coverage_by_sample",
    "HLA_TYPING_COLUMNS",
    "HLA_SOURCE_TYPES",
    "HLA_MVP_LOCI",
    "HLA_CLASS_I_LOCI",
    "HLA_CLASS_II_LOCI"
  )) {
    .hla_obj <- tryCatch(
      utils::getFromNamespace(.hla_fn, "cerebroAppLite"),
      error = function(e) NULL
    )
    if (!is.null(.hla_obj)) {
      assign(.hla_fn, .hla_obj)
    }
  }
  rm(.hla_fn, .hla_obj)
}
