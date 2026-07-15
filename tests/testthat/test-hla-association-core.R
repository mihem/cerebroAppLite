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
