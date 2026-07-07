# test-app-trajectory.R — shinytest2 integration tests for trajectory module
#
# The bundled app loads three demo data sets; the default landing set
# ("PBMC - Full (T+B)" -> demo_full_tcr_bcr.crb) now carries the monocle2
# B-cell trajectory, so the Trajectory tab is present from the start.

library(shinytest2)

inst_candidates <- c(
  normalizePath("inst", mustWork = FALSE),
  normalizePath("../../inst", mustWork = FALSE),
  normalizePath(testthat::test_path("../../inst"), mustWork = FALSE)
)
inst_dir <- inst_candidates[file.exists(file.path(inst_candidates, "app.R"))][1]
if (is.na(inst_dir)) {
  inst_dir <- system.file(package = "cerebroAppLite")
}
if (!nzchar(inst_dir) || !file.exists(file.path(inst_dir, "app.R"))) {
  inst_dir <- testthat::test_path("../../inst")
}

test_that("Trajectory tab is present on the default (full T+B) data set", {
  app <- AppDriver$new(
    inst_dir,
    name = "trajectory_visible",
    height = 950,
    width = 1619,
    load_timeout = 60000
  )
  on.exit(app$stop(), add = TRUE)
  app$wait_for_idle(timeout = 20000)

  # Default data set now carries trajectory data -> tab present immediately.
  tab_present <- app$get_js(
    'document.querySelector(\'a[href="#shiny-tab-trajectory"]\') !== null;'
  )
  expect_true(tab_present)
})

test_that("trajectory module loads without breaking the main app", {
  app <- AppDriver$new(
    inst_dir,
    name = "trajectory_load",
    height = 950,
    width = 1619,
    load_timeout = 60000
  )
  on.exit(app$stop(), add = TRUE)
  app$wait_for_idle(timeout = 20000)

  # Default data set (1,476 cells) now carries the trajectory; confirm the
  # Data info tab still renders its cell count normally alongside it.
  cells_box <- app$get_value(output = "load_data_number_of_cells")
  expect_true(grepl("1,476", cells_box$html))
})
