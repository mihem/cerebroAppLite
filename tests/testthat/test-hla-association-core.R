# Tests for descriptive feature x HLA overlap. These functions intentionally
# perform no inferential statistics.

make_overlap_typing <- function() {
  hla_normalize_typing(
    data.frame(
      sample = c("s1", "s2", "s3", "s4"),
      donor_id = c("d1", "d1", "d2", "d3"),
      locus = c("HLA-A", "HLA-A", "HLA-A", "HLA-B"),
      allele = c(
        "HLA-A*02:01",
        "HLA-A*02:01",
        "HLA-A*01:01",
        "HLA-B*08:01"
      ),
      stringsAsFactors = FALSE
    ),
    source_type = "genotyped"
  )
}

make_overlap_segments <- function() {
  data.frame(
    sample = c("s1", "s1", "s2", "s2", "s3", "s3", "s4"),
    cdr3 = c("CASSL", "CASSL", "CASSF", "OTHER", "CASSL", "OTHER", "OTHER"),
    stringsAsFactors = FALSE
  )
}

test_that("analysis unit collapses samples only with complete donor mapping", {
  typing <- make_overlap_typing()

  donor_map <- hla_analysis_unit_map(typing, c("s1", "s2", "s3"))
  expect_true(all(donor_map$unit_type == "donor"))
  expect_equal(donor_map$analysis_unit, c("d1", "d1", "d2"))

  typing$donor_id[typing$sample == "s3"] <- NA_character_
  sample_map <- hla_analysis_unit_map(typing, c("s1", "s2", "s3"))
  expect_true(all(sample_map$unit_type == "sample"))
  expect_equal(sample_map$analysis_unit, c("s1", "s2", "s3"))
})

test_that("allele status is locus-specific at the analysis-unit level", {
  typing <- make_overlap_typing()

  status <- hla_allele_status_by_unit(
    typing,
    samples = c("s1", "s2", "s3", "s4"),
    allele = "HLA-A*02:01"
  )

  expect_equal(status$hla_status[status$analysis_unit == "d1"], "carrier")
  expect_equal(status$hla_status[status$analysis_unit == "d2"], "non-carrier")
  expect_equal(status$hla_status[status$analysis_unit == "d3"], "untyped")
})

test_that("feature overlap reports donor-level presence breadth and cell fraction", {
  overlap <- hla_descriptive_feature_overlap(
    typing = make_overlap_typing(),
    segments = make_overlap_segments(),
    samples = c("s1", "s2", "s3", "s4"),
    allele = "HLA-A*02:01",
    feature_cdr3 = c("CASSL", "CASSF")
  )

  d1 <- overlap[overlap$analysis_unit == "d1", ]
  expect_true(d1$feature_present)
  expect_equal(d1$n_cells, 4L)
  expect_equal(d1$n_feature_cells, 3L)
  expect_equal(d1$n_unique_clonotypes, 3L)
  expect_equal(d1$n_feature_clonotypes, 2L)
  expect_equal(d1$unique_clonotype_fraction, 2 / 3)
  expect_equal(d1$cell_fraction, 3 / 4)
  expect_equal(d1$hla_status, "carrier")

  d3 <- overlap[overlap$analysis_unit == "d3", ]
  expect_false(d3$feature_present)
  expect_equal(d3$hla_status, "untyped")
})

test_that("feature overlap can freeze V-specific members", {
  typing <- hla_normalize_typing(
    list(s1 = "HLA-A*02:01"),
    source_type = "genotyped"
  )
  segments <- data.frame(
    sample = c("s1", "s1"),
    v_gene = c("TRBV1", "TRBV9"),
    cdr3 = c("CASSL", "CASSL"),
    stringsAsFactors = FALSE
  )

  overlap <- hla_descriptive_feature_overlap(
    typing = typing,
    segments = segments,
    samples = "s1",
    allele = "HLA-A*02:01",
    feature_cdr3 = "CASSL",
    feature_v_gene = "TRBV1"
  )

  expect_equal(overlap$n_feature_cells, 1L)
  expect_equal(overlap$n_unique_clonotypes, 2L)
  expect_equal(overlap$n_feature_clonotypes, 1L)
  expect_equal(overlap$unique_clonotype_fraction, 0.5)
  expect_equal(overlap$cell_fraction, 0.5)
})

## ---- per-node carrier status (render-time colouring) ------------------- ##

test_that("node carrier status summarises the node's samples for one allele", {
  typing <- make_overlap_typing()
  samples <- c("s1", "s2", "s3", "s4")
  # d1 (s1,s2) carries A*02:01; d2 (s3) is locus-typed non-carrier;
  # d3 (s4) has only HLA-B typing -> untyped at the HLA-A locus.
  status <- hla_node_carrier_status(
    samples_all = c("s1", "s1,s2", "s3", "s1,s3", "s4", "s3,s4"),
    typing = typing,
    samples = samples,
    allele = "HLA-A*02:01"
  )
  expect_equal(status[1], "Carrier") # s1 only
  expect_equal(status[2], "Carrier") # s1+s2, both the same donor d1
  expect_equal(status[3], "Non-carrier") # s3 typed at HLA-A, lacks the allele
  expect_equal(status[4], "Mixed") # carrier + non-carrier
  expect_equal(status[5], "Untyped") # s4 has no HLA-A typing
  # untyped alongside a non-carrier must not invent a carrier class
  expect_equal(status[6], "Non-carrier")
})

test_that("carrier counts expose untyped units a label alone would hide", {
  # s1 carries A*02:01; s2 is typed at HLA-B only -> untyped at the HLA-A locus.
  typing <- hla_normalize_typing(
    data.frame(
      sample = c("s1", "s2"),
      locus = c("HLA-A", "HLA-B"),
      allele = c("HLA-A*02:01", "HLA-B*08:01"),
      stringsAsFactors = FALSE
    ),
    source_type = "genotyped"
  )
  samples <- c("s1", "s2")
  st <- hla_node_carrier_status("s1,s2", typing, samples, "HLA-A*02:01")
  cnt <- hla_node_carrier_counts("s1,s2", typing, samples, "HLA-A*02:01")
  # The label says Carrier ("no evidence against"), and the counts must reveal
  # that half the node's units were never typed at this locus.
  expect_equal(st, "Carrier")
  expect_equal(cnt$n_carrier, 1L)
  expect_equal(cnt$n_noncarrier, 0L)
  expect_equal(cnt$n_untyped, 1L)
})

test_that("carrier label is always consistent with its counts", {
  typing <- make_overlap_typing()
  samples <- c("s1", "s2", "s3", "s4")
  nodes <- c("s1", "s3", "s1,s3", "s4", "s3,s4", NA_character_)
  st <- hla_node_carrier_status(nodes, typing, samples, "HLA-A*02:01")
  cnt <- hla_node_carrier_counts(nodes, typing, samples, "HLA-A*02:01")
  derived <- ifelse(
    cnt$n_carrier > 0 & cnt$n_noncarrier > 0,
    "Mixed",
    ifelse(
      cnt$n_carrier > 0,
      "Carrier",
      ifelse(cnt$n_noncarrier > 0, "Non-carrier", "Untyped")
    )
  )
  expect_equal(st, derived)
})

test_that("carrier counts count donors once, not each of their samples", {
  # s1 and s2 are the same donor d1: a node in both is ONE carrier unit.
  typing <- make_overlap_typing()
  cnt <- hla_node_carrier_counts(
    "s1,s2",
    typing,
    c("s1", "s2", "s3", "s4"),
    "HLA-A*02:01"
  )
  expect_equal(cnt$n_carrier, 1L)
})

test_that("node carrier status is Untyped without usable typing", {
  empty <- hla_normalize_typing(list(), source_type = "unknown")
  status <- hla_node_carrier_status(
    samples_all = c("s1", "s2"),
    typing = empty,
    samples = c("s1", "s2"),
    allele = "HLA-A*02:01"
  )
  expect_equal(status, c("Untyped", "Untyped"))
})

test_that("node carrier status handles empty and NA sample sets", {
  typing <- make_overlap_typing()
  expect_equal(
    hla_node_carrier_status(character(0), typing, "s1", "HLA-A*02:01"),
    character(0)
  )
  expect_equal(
    hla_node_carrier_status(NA_character_, typing, "s1", "HLA-A*02:01"),
    "Untyped"
  )
})

test_that("unit by allele matrix distinguishes non-carrier from locus-untyped", {
  mat <- hla_unit_allele_matrix(
    make_overlap_typing(),
    samples = c("s1", "s2", "s3", "s4")
  )

  expect_equal(mat[mat$analysis_unit == "d1", "HLA-A*02:01"], 1L)
  expect_equal(mat[mat$analysis_unit == "d2", "HLA-A*02:01"], 0L)
  expect_true(is.na(mat[mat$analysis_unit == "d3", "HLA-A*02:01"]))
  expect_equal(mat[mat$analysis_unit == "d3", "HLA-B*08:01"], 1L)
})
