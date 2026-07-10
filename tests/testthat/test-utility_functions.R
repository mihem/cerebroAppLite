## Unit tests for helper functions defined in
## inst/shiny/v1.4/utility_functions.R.
##
## These functions live in the Shiny app tree (not the package R/ namespace),
## so they are loaded by sourcing the file into a throw-away environment. They
## are pure R and require neither a running app nor Seurat.
##
## Coverage focuses on the edge cases that previously crashed the app at
## runtime: NA-only percentage columns, NULL/NA toggle inputs, and a missing
## grouping column. See the git history of utility_functions.R for context.

## Prefer the installed copy (mirrors how test-app-inst.R locates the app),
## falling back to the source tree when running against an uninstalled
## checkout (e.g. devtools::load_all()).
utils_file <- system.file(
  "shiny",
  "v1.4",
  "utility_functions.R",
  package = "cerebroAppLite"
)
if (!nzchar(utils_file) || !file.exists(utils_file)) {
  utils_file <- testthat::test_path(
    "..",
    "..",
    "inst",
    "shiny",
    "v1.4",
    "utility_functions.R"
  )
}
skip_if_not(file.exists(utils_file), "utility_functions.R not found")

utils_env <- new.env()
source(utils_file, local = utils_env)
prettifyTable <- utils_env$prettifyTable
centerOfGroups <- utils_env$centerOfGroups

## ---------------------------------------------------------------------------
## centerOfGroups
## ---------------------------------------------------------------------------

test_that("centerOfGroups computes 2D medians per group", {
  result <- centerOfGroups(
    coordinates = list(c(0, 10, 2), c(0, 10, 12)),
    df = data.frame(grp = c("A", "A", "B")),
    n_dimensions = 2,
    group = "grp"
  )
  result <- as.data.frame(result)
  expect_setequal(result$group, c("A", "B"))
  expect_equal(result$x_median[result$group == "A"], 5)
  expect_equal(result$y_median[result$group == "A"], 5)
  expect_equal(result$x_median[result$group == "B"], 2)
  expect_equal(result$y_median[result$group == "B"], 12)
})

test_that("centerOfGroups returns a typed empty tibble for a missing group column", {
  result <- centerOfGroups(
    coordinates = matrix(c(1, 2, 3, 4), ncol = 2),
    df = data.frame(cluster = c("a", "b")),
    n_dimensions = 2,
    group = "does_not_exist"
  )
  expect_equal(nrow(result), 0)
  expect_true(all(
    c("group", "x_median", "y_median", "z_median") %in% colnames(result)
  ))
})

test_that("centerOfGroups returns a typed empty tibble for a NULL group", {
  result <- centerOfGroups(
    coordinates = matrix(c(1, 2, 3, 4), ncol = 2),
    df = data.frame(cluster = c("a", "b")),
    n_dimensions = 2,
    group = NULL
  )
  expect_equal(nrow(result), 0)
})

## ---------------------------------------------------------------------------
## prettifyTable edge cases
## ---------------------------------------------------------------------------

test_that("prettifyTable does not crash on an all-NA percentage column", {
  ## Old code did `if (max(col > 1))`, which returned NA for an all-NA column
  ## and threw "missing value where TRUE/FALSE needed".
  table <- data.frame(
    gene = c("g1", "g2"),
    percent_mt = c(NA_real_, NA_real_)
  )
  expect_no_error(
    prettifyTable(
      table,
      filter = "none",
      dom = "t",
      number_formatting = TRUE,
      columns_percentage = 2
    )
  )
})

test_that("prettifyTable still rescales a 0-100 percentage column to 0-1", {
  table <- data.frame(
    gene = c("g1", "g2", "g3"),
    percent_mt = c(50, NA_real_, 20)
  )
  widget <- prettifyTable(
    table,
    filter = "none",
    dom = "t",
    number_formatting = TRUE,
    columns_percentage = 2
  )
  ## The rescaled values live in the widget's data payload.
  rescaled <- widget$x$data$percent_mt
  expect_equal(rescaled[!is.na(rescaled)], c(0.5, 0.2))
})

test_that("prettifyTable tolerates NA / NULL toggle inputs", {
  table <- data.frame(
    gene = c("g1", "g2"),
    percent_mt = c(10, 20)
  )
  ## materialSwitch can transiently pass NA / NULL during UI re-render.
  expect_no_error(
    prettifyTable(table, filter = "none", dom = "t", number_formatting = NA)
  )
  expect_no_error(
    prettifyTable(table, filter = "none", dom = "t", show_buttons = NULL)
  )
  expect_no_error(
    prettifyTable(table, filter = "none", dom = "t", hide_long_columns = NA)
  )
})
