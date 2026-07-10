# test-spatial-morans-i.R — unit tests for Moran's I spatial autocorrelation.
#
# Moran's I scores whether a gene's expression is spatially clustered: ~+1 when
# high and low cells segregate into patches, ~0 for a random spatial pattern,
# and negative when neighbouring cells tend to be dissimilar (checkerboard).
# Weights are binary k-nearest-neighbour (each cell's k closest neighbours by
# Euclidean distance count 1, others 0).

mi <- morans_i

test_that("a segregated high/low split is strongly positive", {
  # Two well-separated clusters: left cells all low, right cells all high.
  coords <- expand.grid(x = 1:6, y = 1:6)
  vals <- ifelse(coords$x <= 3, 0, 10)
  out <- mi(coords$x, coords$y, vals, k = 4)
  expect_gt(out, 0.5)
})

test_that("a checkerboard pattern is negative", {
  coords <- expand.grid(x = 1:6, y = 1:6)
  vals <- ifelse((coords$x + coords$y) %% 2 == 0, 0, 10)
  out <- mi(coords$x, coords$y, vals, k = 4)
  expect_lt(out, 0)
})

test_that("constant expression yields (near) zero, never NaN", {
  coords <- expand.grid(x = 1:5, y = 1:5)
  vals <- rep(3, nrow(coords))
  out <- mi(coords$x, coords$y, vals, k = 4)
  # zero variance -> defined as 0 (no autocorrelation signal), not NaN
  expect_equal(out, 0)
})

test_that("result stays within [-1, 1]", {
  set.seed(1)
  coords <- expand.grid(x = 1:8, y = 1:8)
  vals <- rnorm(nrow(coords))
  out <- mi(coords$x, coords$y, vals, k = 5)
  expect_true(out >= -1 && out <= 1)
})

test_that("a smooth gradient is positive (nearby cells are similar)", {
  coords <- expand.grid(x = 1:7, y = 1:7)
  vals <- coords$x # increases smoothly across space
  out <- mi(coords$x, coords$y, vals, k = 4)
  expect_gt(out, 0.3)
})

test_that("NA expression cells are dropped, not treated as zero", {
  coords <- expand.grid(x = 1:6, y = 1:6)
  vals <- ifelse(coords$x <= 3, 0, 10)
  vals[1] <- NA
  out <- mi(coords$x, coords$y, vals, k = 4)
  expect_false(is.na(out))
  expect_gt(out, 0.4)
})

test_that("too few cells to form k neighbours returns NA", {
  out <- mi(c(1, 2), c(1, 2), c(5, 9), k = 4)
  expect_true(is.na(out))
})
