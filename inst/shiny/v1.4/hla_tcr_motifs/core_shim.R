##----------------------------------------------------------------------------##
## HLA & TCR Motifs — core function shim
##
## The pure motif / HLA-typing core lives in the package R/ directory so it is
## installed and unit-tested. The Shiny app, however, is also commonly launched
## straight from the repository with runApp("inst"). In that mode the installed
## package can legitimately be older than the checked-out source tree.
##
## This file is sourced with local = TRUE into the module server scope, so the
## assignments below land in that scope and every other module file can call the
## core functions by bare name. A repository launch sources the current core R
## files first; an installed-app launch falls back to the package namespace. We
## use getFromNamespace() — an explicit, documented API — NOT the ::: operator
## that the project bans in runtime code.
##----------------------------------------------------------------------------##

## Prefer the checked-out package source when this app is launched from <repo>/
## inst. This keeps runApp("inst") coherent even when the user has an older
## cerebroAppLite installed in their library. Installed packages do not retain
## these R/*.R source files, so production launches naturally take the namespace
## path below.
.hla_app_root <- NULL
.hla_options <- NULL
if (exists("Cerebro.options", inherits = TRUE)) {
  .hla_options <- get("Cerebro.options", inherits = TRUE)
  if (!is.null(.hla_options[["cerebro_root"]])) {
    .hla_app_root <- tryCatch(
      normalizePath(.hla_options[["cerebro_root"]], mustWork = TRUE),
      error = function(e) NULL
    )
  }
}
.hla_source_root <- if (!is.null(.hla_app_root)) {
  normalizePath(file.path(.hla_app_root, ".."), mustWork = FALSE)
} else {
  NULL
}
## Every core file the module calls into. A file missing here fails ONLY on a
## repository launch (the namespace path below sees the whole package), so the
## omission survives unit tests and surfaces as "could not find function" in a
## running app. tests/testthat/test-hla-app-contract.R pins both lists.
.hla_source_files <- c(
  "hla_typing.R",
  "hla_motif_core.R",
  "hla_association_core.R",
  "hla_visual_helpers.R",
  "hla_export.R"
)
.hla_source_paths <- if (!is.null(.hla_source_root)) {
  file.path(.hla_source_root, "R", .hla_source_files)
} else {
  character(0)
}
.hla_has_source_tree <-
  !is.null(.hla_source_root) &&
  file.exists(file.path(.hla_source_root, "DESCRIPTION")) &&
  length(.hla_source_paths) == length(.hla_source_files) &&
  all(file.exists(.hla_source_paths))

if (.hla_has_source_tree) {
  for (.hla_source_path in .hla_source_paths) {
    sys.source(.hla_source_path, envir = environment())
  }
  rm(.hla_source_path)
} else if (requireNamespace("cerebroAppLite", quietly = TRUE)) {
  ## requireNamespace() loads (not attaches) the installed package if needed.
  ## This path supports a normal installed-app launch, where package code and
  ## app resources come from the same installed build.
  for (.hla_fn in c(
    "hla_detect_chains",
    "hla_parse_ir_segments",
    "hla_make_consensus",
    "hla_motif_variable_aa",
    "hla_build_motif_graph",
    "hla_motif_graph_ok",
    "hla_motif_layout",
    "HLA_LAYOUT_SEED",
    "HLA_MOTIF_MAX_RENDER",
    "hla_lineage_context",
    "hla_context_summary",
    "hla_normalize_typing",
    "hla_read_typing_file",
    "hla_normalize_allele",
    "hla_allele_resolution",
    "hla_allele_locus",
    "hla_locus_class",
    "hla_is_typing_table",
    "hla_carrier_index",
    "hla_allele_compare",
    "hla_carriers_of",
    "hla_pair_class_summary",
    "HLA_PAIR_MIXED_LABEL",
    "hla_scope_segments_by_allele_pair",
    "HLA_CLASS_II_LOCI",
    "hla_allele_carrier_summary",
    "hla_node_carrier_status",
    "hla_node_carrier_counts",
    "hla_node_sample_origin",
    "hla_scope_segments_by_allele",
    "hla_build_manifest",
    "hla_graph_tables",
    "hla_motif_summary",
    "hla_analysis_unit_map",
    "hla_allele_status_by_unit",
    "hla_descriptive_feature_overlap",
    "hla_unit_allele_matrix",
    "hla_coverage_by_sample",
    "hla_distinct_colors",
    "hla_node_radius",
    "HLA_TYPING_COLUMNS",
    "HLA_SOURCE_TYPES",
    "HLA_MVP_LOCI",
    "HLA_CLASS_I_LOCI",
    "HLA_CLASS_II_LOCI",
    "HLA_SHARED_LABEL",
    "HLA_NODE_R_MIN",
    "HLA_NODE_R_MAX",
    "HLA_NODE_MAX_EXACT"
  )) {
    .hla_obj <- tryCatch(
      utils::getFromNamespace(.hla_fn, "cerebroAppLite"),
      error = function(e) NULL
    )
    if (!is.null(.hla_obj)) {
      # This file is sourced with local = TRUE into the app-server evaluation
      # environment. Bind there so sibling module files resolve the names while
      # parallel app sessions and the process global environment remain clean.
      assign(.hla_fn, .hla_obj, envir = environment())
    }
  }
  rm(.hla_fn, .hla_obj)
}

rm(
  .hla_app_root,
  .hla_options,
  .hla_source_root,
  .hla_source_files,
  .hla_source_paths,
  .hla_has_source_tree
)
