## ---------------------------------------------------------------------------
## Anti-drift guard: R/spatial-helpers.R vs inst/.../func_spatial_helpers.R
##
## The spatial helpers exist in TWO copies on purpose:
##   - R/spatial-helpers.R          -> compiled into the package namespace;
##                                     the tested API (cerebroAppLite:::helper).
##   - inst/shiny/v1.4/spatial/func_spatial_helpers.R
##                                  -> source()d into the Shiny server scope so
##                                     the Spatial tab works in a plain
##                                     runApp("inst") session WITHOUT the package
##                                     installed (bare-name calls).
##
## Only inst/shiny/ is guaranteed to exist across all three launch paths
## (runApp("inst"), an installed package's system.file("shiny"), and a
## createShinyApp() bundle, which copies ONLY inst/shiny + inst/extdata and
## never R/). So the duplication cannot be removed by having the app source
## R/spatial-helpers.R — that file is absent from a bundle.
##
## This test welds the two copies together: every helper must have byte-identical
## body and identical formals in both files. If someone edits one and forgets the
## other, this fails loudly instead of shipping a silent divergence.
## ---------------------------------------------------------------------------

test_that("spatial helpers are identical in R/ and inst/ copies", {
  helper_names <- c(
    "resolve_spatial_image_preset",
    "format_spatial_preset_code",
    "compute_group_hulls",
    "blend_genes_to_rgb",
    "morans_i"
  )

  r_path <- testthat::test_path("..", "..", "R", "spatial-helpers.R")
  inst_path <- testthat::test_path(
    "..",
    "..",
    "inst",
    "shiny",
    "v1.4",
    "spatial",
    "func_spatial_helpers.R"
  )
  skip_if_not(file.exists(r_path), "R/spatial-helpers.R not found")
  skip_if_not(file.exists(inst_path), "inst copy not found")

  source_env <- function(path) {
    env <- new.env(parent = baseenv())
    sys.source(path, envir = env)
    env
  }
  r_env <- source_env(r_path)
  inst_env <- source_env(inst_path)

  for (nm in helper_names) {
    expect_true(
      exists(nm, envir = r_env, inherits = FALSE),
      info = paste0(nm, " missing from R/spatial-helpers.R")
    )
    expect_true(
      exists(nm, envir = inst_env, inherits = FALSE),
      info = paste0(nm, " missing from inst func_spatial_helpers.R")
    )

    r_fn <- get(nm, envir = r_env)
    inst_fn <- get(nm, envir = inst_env)

    ## Formals must match name-for-name (and defaults).
    expect_identical(
      formals(r_fn),
      formals(inst_fn),
      info = paste0("formals differ for ", nm)
    )

    ## Bodies must be byte-identical after deparse (ignores surrounding comments
    ## but catches any logic change in either copy).
    expect_identical(
      deparse(body(r_fn)),
      deparse(body(inst_fn)),
      info = paste0("body differs for ", nm, " — the two copies have drifted")
    )
  }
})
