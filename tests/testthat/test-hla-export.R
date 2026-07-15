# Tests for the analysis export (R/hla_export.R). Pure functions.

make_export_graph <- function() {
  df <- data.frame(
    barcode = c("a", "b", "c"),
    CTgene = "TRBV1.TRBJ2",
    CTaa = c("CASSL", "CASSF", "CWWWW"),
    sample = c("s1", "s2", "s1"),
    stringsAsFactors = FALSE
  )
  seg <- hla_parse_ir_segments(list(s1 = df), "TRB")
  hla_build_motif_graph(seg, min_nodes = 2L, meta_cols = "sample")
}

## ---- manifest --------------------------------------------------------- ##

test_that("manifest records the parameters needed to recompute the view", {
  m <- hla_build_manifest(
    dataset = "demo",
    chain = "TRB",
    input_channel = "stored .crb",
    hla_source_type = "genotyped",
    unit_type = "donor",
    observation_unit = "cell",
    n_units = 10,
    n_nodes = 5,
    n_edges = 4,
    n_motifs = 2,
    min_nodes = 3,
    split_by_v = TRUE,
    show_isolated = FALSE,
    allele = "HLA-A*02:01",
    app_version = "9.9.9"
  )
  val <- function(f) m$value[m$field == f]
  expect_equal(val("dataset"), "demo")
  expect_equal(val("statistical_unit"), "donor")
  expect_equal(val("hla_source_type"), "genotyped")
  expect_equal(val("minimum_motif_nodes"), "3")
  expect_equal(val("node_key"), "V gene + CDR3")
  expect_equal(val("cerebroAppLite_version"), "9.9.9")
  # The edge rule is fixed, and the export must say so rather than leave a
  # reader to assume some other distance was used.
  expect_match(val("edge_rule"), "Hamming distance == 1")
})

test_that("manifest states the evidence ceiling and the denominator", {
  m <- hla_build_manifest(
    dataset = "d",
    chain = "TRB",
    input_channel = "none",
    hla_source_type = NA_character_,
    unit_type = "sample",
    observation_unit = "cell",
    n_units = 1,
    n_nodes = 1,
    n_edges = 0,
    n_motifs = 0,
    min_nodes = 2,
    split_by_v = FALSE,
    show_isolated = FALSE
  )
  val <- function(f) m$value[m$field == f]
  # Tables outlive the app; they must carry their own ceiling.
  expect_match(val("evidence_level"), "not.*confirmed TCR", ignore.case = TRUE)
  expect_match(val("evidence_level"), "No hypothesis test")
  expect_match(val("fraction_denominator"), "not the")
  expect_equal(val("node_key"), "CDR3")
  expect_equal(val("hla_allele_shown"), "(none)")
})

test_that("an association-conditioned data set gets a warning in the export", {
  m <- hla_build_manifest(
    dataset = "d",
    chain = "TRB",
    input_channel = "stored .crb",
    hla_source_type = "genotyped",
    unit_type = "donor",
    observation_unit = "analysis unit",
    n_units = 100,
    n_nodes = 10,
    n_edges = 9,
    n_motifs = 1,
    min_nodes = 2,
    split_by_v = TRUE,
    show_isolated = FALSE,
    tcr_selection = "association-conditioned"
  )
  w <- m$value[m$field == "interpretation_warning"]
  expect_length(w, 1L)
  expect_match(w, "POSITIVE CONTROL")
  expect_match(w, "not independent evidence")
})

test_that("manifest carries QC warnings", {
  m <- hla_build_manifest(
    dataset = "d",
    chain = "TRB",
    input_channel = "session upload",
    hla_source_type = "unknown",
    unit_type = "sample",
    observation_unit = "cell",
    n_units = 2,
    n_nodes = 2,
    n_edges = 1,
    n_motifs = 1,
    min_nodes = 2,
    split_by_v = FALSE,
    show_isolated = FALSE,
    qc_warnings = c("bad allele", "unmapped sample")
  )
  expect_match(m$value[m$field == "qc_warnings"], "bad allele")
  expect_match(m$value[m$field == "qc_warnings"], "unmapped sample")
})

## ---- graph tables ----------------------------------------------------- ##

test_that("graph tables export nodes and edges", {
  g <- make_export_graph()
  tabs <- hla_graph_tables(g)
  expect_equal(nrow(tabs$nodes), 2L) # CASSL + CASSF connect; CWWWW isolated
  expect_equal(nrow(tabs$edges), 1L)
  expect_true("cdr3" %in% colnames(tabs$nodes))
})

test_that("graph tables are empty frames for an unusable graph", {
  tabs <- hla_graph_tables(NULL)
  expect_equal(nrow(tabs$nodes), 0L)
  expect_equal(nrow(tabs$edges), 0L)
})

## ---- motif summary ---------------------------------------------------- ##

test_that("motif summary reports size, consensus and diameter", {
  g <- make_export_graph()
  s <- hla_motif_summary(g)
  expect_equal(nrow(s), 1L)
  expect_equal(s$n_cdr3, 2L)
  expect_equal(s$consensus, "CASSx")
  # Diameter travels with the summary: component membership is transitive, so
  # a reader must not assume every pair is within distance 1.
  expect_equal(s$diameter, 1L)
})

test_that("motif summary is an empty frame for an unusable graph", {
  expect_equal(nrow(hla_motif_summary(NULL)), 0L)
})
