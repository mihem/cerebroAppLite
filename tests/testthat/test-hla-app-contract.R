hla_inst_file <- function(...) {
  installed <- system.file(..., package = "cerebroAppLite")
  if (nzchar(installed) && file.exists(installed)) {
    return(installed)
  }
  testthat::test_path("../../inst", ...)
}

test_that("HLA Associations is wired to a frozen motif feature", {
  src <- paste(
    readLines(
      hla_inst_file("shiny/v1.4/hla_tcr_motifs/associations.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(src, "hla_feature_type")
  expect_match(src, "hla_feature_id")
  expect_match(src, "hla_descriptive_feature_overlap", fixed = TRUE)
  expect_match(src, "hla_overlap_table")
  expect_match(src, "hla_allele_matrix")
})

test_that("Data and QC exposes normalized and donor mapping previews", {
  src <- paste(
    readLines(
      hla_inst_file("shiny/v1.4/hla_tcr_motifs/data_qc.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(src, "hla_normalized_preview")
  expect_match(src, "hla_donor_mapping_preview")
  expect_match(src, "hla_download_normalized")
})

test_that("motif network exposes a stable selected-node detail panel", {
  ui <- paste(
    readLines(
      hla_inst_file("shiny/v1.4/hla_tcr_motifs/UI.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  viz <- paste(
    readLines(
      hla_inst_file("shiny/v1.4/hla_tcr_motifs/visualizations.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(ui, "hla_node_details")
  expect_match(viz, "hla_selected_node_id")
  expect_match(viz, "visEvents")
})

test_that("core shim binds locally without polluting globalenv", {
  local_env <- new.env(parent = globalenv())
  global_names <- c("hla_detect_chains", "hla_descriptive_feature_overlap")
  for (nm in global_names) {
    if (exists(nm, envir = .GlobalEnv, inherits = FALSE)) {
      rm(list = nm, envir = .GlobalEnv)
    }
  }

  source(
    hla_inst_file("shiny/v1.4/hla_tcr_motifs/core_shim.R"),
    local = local_env
  )

  expect_true(exists("hla_detect_chains", envir = local_env, inherits = FALSE))
  expect_true(exists(
    "hla_descriptive_feature_overlap",
    envir = local_env,
    inherits = FALSE
  ))
  expect_false(exists(
    "hla_detect_chains",
    envir = .GlobalEnv,
    inherits = FALSE
  ))
  expect_false(exists(
    "hla_descriptive_feature_overlap",
    envir = .GlobalEnv,
    inherits = FALSE
  ))
})

test_that("source-tree core shim does not require a freshly installed package", {
  repo_root <- normalizePath(testthat::test_path("../.."), mustWork = TRUE)
  app_root <- file.path(repo_root, "inst")
  shim_path <- file.path(
    app_root,
    "shiny/v1.4/hla_tcr_motifs/core_shim.R"
  )
  expression <- paste0(
    "e <- new.env(parent = globalenv()); ",
    "e$Cerebro.options <- list(cerebro_root = ",
    deparse(app_root),
    "); ",
    "sys.source(",
    deparse(shim_path),
    ", envir = e); ",
    "stopifnot(",
    "exists('hla_distinct_colors', envir = e, inherits = FALSE), ",
    "exists('hla_descriptive_feature_overlap', envir = e, inherits = FALSE)",
    ")"
  )
  output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote(expression)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
})

test_that("bundled HLA demo states synthetic receptor-to-cell linkage", {
  app <- paste(readLines(hla_inst_file("app.R"), warn = FALSE), collapse = "\n")

  datasets_path <- testthat::test_path("../../data-raw/DATASETS.md")
  if (file.exists(datasets_path)) {
    datasets <- paste(readLines(datasets_path, warn = FALSE), collapse = "\n")
    expect_match(
      datasets,
      "synthetic receptor-to-cell linkage",
      ignore.case = TRUE
    )
  }
  expect_match(app, "synthetic TCR linkage", ignore.case = TRUE)
})

## ---- shipped demo contracts ------------------------------------------- ##
## The bulk demo makes claims the UI depends on. If a rebuild drops one, the
## page silently changes meaning: donor-level counting reverts to sample-level,
## or the positive-control disclosure disappears while the contrast remains.

hla_bulk_demo <- function() {
  path <- hla_inst_file("extdata/v1.4/demo_hla_tcr_bulk.crb")
  testthat::skip_if_not(file.exists(path), "bulk demo not built")
  readRDS(path)
}

test_that("bulk demo declares its association-conditioned selection", {
  ti <- hla_bulk_demo()$technical_info
  expect_equal(ti$tcr_selection, "association-conditioned")
  expect_true(nzchar(ti$tcr_selection_detail))
})

test_that("bulk demo declares a V-gene+CDR3 receptor key", {
  # Its CDR3s recur across V families, so CDR3-only nodes would fuse receptors
  # the source counts separately.
  expect_equal(hla_bulk_demo()$technical_info$receptor_key, "v_gene+cdr3")
})

test_that("bulk demo carries donor ids, so counting is donor-level", {
  ht <- hla_bulk_demo()$getHLATyping()
  expect_false(any(is.na(ht$donor_id)))
  units <- hla_analysis_unit_map(ht, unique(ht$sample))
  expect_equal(unique(units$unit_type), "donor")
})

test_that("bulk demo HLA is real, and measures no genes", {
  crb <- hla_bulk_demo()
  expect_true(all(crb$getHLATyping()$source_type == "genotyped"))
  # Bulk: no transcriptome. A 0-row matrix states that; NULL would break
  # ncol()/nrow() call sites.
  expect_equal(nrow(crb$expression), 0L)
  expect_equal(ncol(crb$expression), nrow(crb$meta_data))
})
