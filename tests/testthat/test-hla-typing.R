# Tests for HLA typing normalization (R/hla_typing.R). Pure functions.

## ---- allele normalization --------------------------------------------- ##

test_that("allele normalization accepts common input forms", {
  expect_equal(hla_normalize_allele("HLA-A*02:01"), "HLA-A*02:01")
  expect_equal(hla_normalize_allele("A*02:01"), "HLA-A*02:01")
  expect_equal(hla_normalize_allele("02:01", locus = "HLA-A"), "HLA-A*02:01")
  expect_equal(hla_normalize_allele("a*02:01"), "HLA-A*02:01") # case-fold
})

test_that("allele normalization treats NNNN / empty / NA as missing", {
  expect_true(is.na(hla_normalize_allele("NNNN")))
  expect_true(is.na(hla_normalize_allele("")))
  expect_true(is.na(hla_normalize_allele(NA)))
  expect_true(is.na(hla_normalize_allele("NA")))
})

test_that("bare fields without a locus are unrecognisable", {
  expect_true(is.na(hla_normalize_allele("02:01")))
})

test_that("resolution is preserved, not padded", {
  expect_equal(hla_allele_resolution("HLA-A*02"), "1-field")
  expect_equal(hla_allele_resolution("HLA-A*02:01"), "2-field")
  expect_equal(hla_allele_resolution("HLA-A*02:01:01"), "3-field")
})

test_that("expression suffix is accepted", {
  expect_equal(hla_normalize_allele("HLA-A*02:01N"), "HLA-A*02:01N")
})

test_that("official G and P group suffixes are preserved", {
  expect_equal(
    hla_normalize_allele("HLA-A*02:01:01G"),
    "HLA-A*02:01:01G"
  )
  expect_equal(hla_normalize_allele("HLA-A*02:01P"), "HLA-A*02:01P")
  expect_equal(hla_allele_resolution("HLA-A*02:01:01G"), "3-field")
  expect_equal(hla_allele_resolution("HLA-A*02:01P"), "2-field")
})

test_that("garbage alleles are rejected", {
  expect_true(is.na(hla_normalize_allele("banana")))
  expect_true(is.na(hla_normalize_allele("A*")))
})

## ---- locus class ------------------------------------------------------ ##

test_that("locus class maps I / II / other", {
  expect_equal(hla_locus_class("HLA-A"), "Class I")
  expect_equal(hla_locus_class("HLA-DRB1"), "Class II")
  expect_equal(hla_locus_class("HLA-E"), "Other")
})

## ---- named-list input ------------------------------------------------- ##

test_that("named list normalizes to canonical long table", {
  x <- list(
    sample_1 = c("HLA-A*02:01", "HLA-A*01:01", "HLA-B*08:01"),
    sample_2 = c("HLA-A*03:01")
  )
  t <- hla_normalize_typing(x, source_type = "genotyped")
  expect_true(hla_is_typing_table(t))
  expect_equal(nrow(t), 4L)
  # copy 1/2 assigned within (sample, locus)
  a <- t[t$sample == "sample_1" & t$locus == "HLA-A", ]
  expect_setequal(a$copy, c(1L, 2L))
  expect_true(all(t$source_type == "genotyped"))
})

## ---- wide input (57.R style) ------------------------------------------ ##

test_that("wide table normalizes to canonical long table", {
  wide <- data.frame(
    sample = c("s1", "s2"),
    `HLA-A_1` = c("02:01", "01:01"),
    `HLA-A_2` = c("33:01", "NNNN"),
    `HLA-B_1` = c("08:01", "40:01"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  t <- hla_normalize_typing(wide, source_type = "genotyped")
  expect_true(hla_is_typing_table(t))
  # s1 has A*02:01, A*33:01, B*08:01; s2 has A*01:01 (A_2 is NNNN -> dropped), B*40:01
  expect_equal(sum(t$sample == "s1"), 3L)
  expect_equal(sum(t$sample == "s2"), 2L)
  expect_true("HLA-A*02:01" %in% t$allele)
  expect_false(any(grepl("NNNN", t$allele)))
})

test_that("wide table preserves donor mapping", {
  wide <- data.frame(
    sample = c("s1", "s2"),
    donor_id = c("d1", "d2"),
    `HLA-A_1` = c("02:01", "01:01"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  t <- hla_normalize_typing(wide, source_type = "genotyped")

  expect_equal(t$donor_id[match(c("s1", "s2"), t$sample)], c("d1", "d2"))
})

test_that("donor_id survives normalization of a long table", {
  # Losing donor_id here silently demotes the whole app to sample-level
  # counting while the UI still says donor-level, so it is contract-critical.
  t <- hla_normalize_typing(
    data.frame(
      sample = c("s1", "s2"),
      donor_id = c("d1", "d1"),
      locus = "HLA-A",
      allele = c("HLA-A*02:01", "HLA-A*01:01"),
      stringsAsFactors = FALSE
    ),
    source_type = "genotyped"
  )
  expect_false(any(is.na(t$donor_id)))
  expect_equal(unique(t$donor_id), "d1")
})

test_that("a named list has no donor column, so donor_id is NA", {
  # The named-list adapter cannot express donors; callers who need donor-level
  # counting must supply a long table (see the test above).
  t <- hla_normalize_typing(
    list(s1 = "HLA-A*02:01"),
    source_type = "genotyped"
  )
  expect_true(all(is.na(t$donor_id)))
})

## ---- provenance safety ------------------------------------------------ ##

test_that("missing source_type defaults to unknown with a QC warning", {
  t <- hla_normalize_typing(list(s1 = "HLA-A*02:01"))
  expect_true(all(t$source_type == "unknown"))
  qc <- attr(t, "qc")
  expect_true(any(grepl("unknown", qc$issue)))
})

test_that("unrecognisable alleles are reported in QC, not silently dropped", {
  t <- hla_normalize_typing(
    list(s1 = c("HLA-A*02:01", "banana")),
    source_type = "genotyped"
  )
  expect_equal(nrow(t), 1L) # only the valid one kept
  qc <- attr(t, "qc")
  expect_true(any(grepl("unrecognisable", qc$issue)))
})

## ---- carrier index + coverage ----------------------------------------- ##

test_that("carrier index maps allele -> samples", {
  x <- list(
    s1 = c("HLA-A*02:01", "HLA-B*08:01"),
    s2 = c("HLA-A*02:01"),
    s3 = c("HLA-A*01:01")
  )
  t <- hla_normalize_typing(x, source_type = "genotyped")
  ci <- hla_carrier_index(t)
  expect_setequal(ci[["HLA-A*02:01"]], c("s1", "s2"))
  expect_setequal(ci[["HLA-A*01:01"]], "s3")
})

test_that("coverage-by-sample summarises loci and allele counts", {
  x <- list(s1 = c("HLA-A*02:01", "HLA-A*01:01", "HLA-B*08:01"))
  t <- hla_normalize_typing(x, source_type = "genotyped")
  cov <- hla_coverage_by_sample(t)
  expect_equal(cov$n_alleles, 3L)
  expect_true(grepl("HLA-A", cov$loci))
  expect_true(grepl("HLA-B", cov$loci))
})

## ---- lineage-derived MHC context -------------------------------------- ##

test_that("lineage context maps CD8 -> Class I, CD4/Treg -> Class II", {
  expect_equal(hla_lineage_context("CD8 T"), "Class I")
  expect_equal(hla_lineage_context("CD8+ T cells"), "Class I")
  expect_equal(hla_lineage_context("CD4 T"), "Class II")
  expect_equal(hla_lineage_context("Treg"), "Class II")
  expect_equal(hla_lineage_context("regulatory (Treg)"), "Class II")
})

test_that("coarse or non-T labels map to Unknown, never guessed", {
  expect_equal(hla_lineage_context("T cells"), "Unknown")
  expect_equal(hla_lineage_context("B cells"), "Unknown")
  expect_equal(hla_lineage_context("Monocytes"), "Unknown")
  expect_equal(hla_lineage_context("T (unassigned)"), "Unknown")
})

test_that("lineage context is vectorised", {
  expect_equal(
    hla_lineage_context(c("CD8 T", "CD4 T", "T cells")),
    c("Class I", "Class II", "Unknown")
  )
})

test_that("context summary collapses per-cell contexts to a node label", {
  expect_equal(hla_context_summary(c("Class I", "Class I")), "Class I")
  expect_equal(hla_context_summary(c("Class II", "Unknown")), "Class II")
  expect_equal(hla_context_summary(c("Class I", "Class II")), "Mixed")
  expect_equal(hla_context_summary(c("Unknown", "Unknown")), "Unknown")
})

## ---- descriptive carrier summary -------------------------------------- ##

test_that("carrier summary counts carriers / non-carriers / untyped", {
  x <- list(
    s1 = c("HLA-A*02:01", "HLA-B*08:01"),
    s2 = c("HLA-A*02:01"),
    s3 = c("HLA-A*01:01")
  )
  t <- hla_normalize_typing(x, source_type = "genotyped")
  # scope includes a 4th sample (s4) with no typing -> untyped
  summ <- hla_allele_carrier_summary(t, samples = c("s1", "s2", "s3", "s4"))
  a2 <- summ[summ$allele == "HLA-A*02:01", ]
  expect_equal(a2$n_carrier, 2L) # s1, s2
  expect_equal(a2$n_noncarrier, 1L) # s3 (typed, lacks it)
  expect_equal(a2$n_untyped, 1L) # s4
  expect_equal(a2$mhc_class, "Class I")
  expect_true(grepl("s1", a2$carriers) && grepl("s2", a2$carriers))
})

test_that("carrier summary uses locus-specific typing denominators", {
  t <- hla_normalize_typing(
    list(
      s1 = c("HLA-A*02:01", "HLA-B*08:01"),
      s2 = "HLA-A*01:01"
    ),
    source_type = "genotyped"
  )

  summ <- hla_allele_carrier_summary(t, samples = c("s1", "s2"))
  b8 <- summ[summ$allele == "HLA-B*08:01", ]

  expect_equal(b8$n_carrier, 1L)
  expect_equal(b8$n_noncarrier, 0L)
  expect_equal(b8$n_untyped, 1L)
})

test_that("carrier summary collapses repeated samples to donor when complete", {
  t <- hla_normalize_typing(
    data.frame(
      sample = c("s1", "s2", "s3"),
      donor_id = c("d1", "d1", "d2"),
      locus = "HLA-A",
      allele = c("HLA-A*02:01", "HLA-A*02:01", "HLA-A*01:01"),
      stringsAsFactors = FALSE
    ),
    source_type = "genotyped"
  )

  summ <- hla_allele_carrier_summary(t, samples = c("s1", "s2", "s3"))
  a2 <- summ[summ$allele == "HLA-A*02:01", ]

  expect_equal(a2$analysis_unit, "donor")
  expect_equal(a2$n_carrier, 1L)
  expect_equal(a2$n_noncarrier, 1L)
  expect_equal(a2$n_untyped, 0L)
  expect_equal(a2$carriers, "d1")
})

test_that("carrier summary is ordered by descending carrier count", {
  x <- list(s1 = "HLA-A*02:01", s2 = "HLA-A*02:01", s3 = "HLA-A*01:01")
  t <- hla_normalize_typing(x, source_type = "genotyped")
  summ <- hla_allele_carrier_summary(t, samples = c("s1", "s2", "s3"))
  expect_equal(summ$allele[1], "HLA-A*02:01") # 2 carriers first
})

test_that("carrier summary is empty on empty typing", {
  t <- hla_normalize_typing(list(), source_type = "genotyped")
  summ <- hla_allele_carrier_summary(t, samples = c("s1"))
  expect_equal(nrow(summ), 0L)
})

## ---- empty input ------------------------------------------------------ ##

test_that("empty input yields an empty canonical table", {
  t <- hla_normalize_typing(list(), source_type = "genotyped")
  expect_true(hla_is_typing_table(t))
  expect_equal(nrow(t), 0L)
})
