# Deployment-hardening contracts (synthesis stage 0).
# These assertions guard the generated standalone bundle against the
# "can this be safely served on a public host?" regressions.

test_that("createShinyApp never exposes the bundled data/ dir as a static URL (S1)", {
  fn_src <- paste(deparse(body(createShinyApp)), collapse = "\n")
  expect_false(
    grepl("addResourcePath\\([\\s\\S]{0,20}[\"']data[\"']", fn_src),
    info = paste(
      "The generated app.R must not call addResourcePath(\"data\", ...).",
      "It would let anyone download the raw .crb/H5 datasets via",
      "/data/<file>, bypassing the UI. Datasets are read server-side",
      "from disk; spatial images are base64-embedded."
    )
  )
})

test_that("createShinyApp defaults to non-destructive overwrite = FALSE (S4)", {
  expect_false(isTRUE(eval(formals(createShinyApp)$overwrite)))
})

test_that("createShinyApp guards the destructive unlink (S4)", {
  fn_src <- paste(deparse(body(createShinyApp)), collapse = "\n")
  # protected-path guard and bundle-marker check must both be present
  expect_true(grepl("protected", fn_src))
  expect_true(grepl("\\.cerebro_bundle", fn_src))
  expect_true(grepl("Refusing to (overwrite|delete)", fn_src))
})

test_that("projection code never shuffles with sample(1:n) (empty-filter 1:0 bug, R3)", {
  shiny_root <- system.file("shiny/v1.4", package = "CerebroNexus")
  skip_if(shiny_root == "", "package not installed")
  r_files <- list.files(
    shiny_root,
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )
  offenders <- Filter(
    function(f) {
      src <- paste(readLines(f, warn = FALSE), collapse = "\n")
      grepl("sample\\(\\s*1:(nrow|NROW|length)\\b", src, perl = TRUE)
    },
    r_files
  )
  expect_identical(
    character(0),
    sub(paste0(shiny_root, "/"), "", offenders, fixed = TRUE),
    info = paste(
      "sample(1:nrow(x)) yields c(1,0) when x has 0 rows (all cells",
      "filtered out), injecting a bogus/NA row. Use seq_len()/seq_along()."
    )
  )
})
