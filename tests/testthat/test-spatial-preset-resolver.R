# test-spatial-preset-resolver.R — unit tests for the per-dataset spatial
# background-image preset resolver.
#
# The spatial tab seeds the background overlay's move / scale / flip from
# per-dataset `spatial_images_*` presets in Cerebro.options. That lookup was
# copy-pasted into three places (UI seed, plot params, Reset). These tests pin
# the pure resolver that replaces all three: given an options list, the set of
# available crb files (a named vector of file -> label) and the selected file,
# return the preset value for the current dataset or a fallback.

resolve <- cerebroAppLite:::resolve_spatial_image_preset

# A minimal fixture: two datasets, one carrying an offset preset.
crb_files <- c(
  "Mouse brain (Visium)" = "visium.crb",
  "Mouse ileum (MERFISH)" = "merfish.crb"
)
opts <- list(
  spatial_images_offset_x = c("Mouse brain (Visium)" = 450),
  spatial_images_flip_y = c("Mouse brain (Visium)" = TRUE)
)

test_that("returns the preset value for the selected dataset", {
  expect_equal(
    resolve("spatial_images_offset_x", 0, opts, crb_files, "visium.crb"),
    450
  )
})

test_that("returns the fallback when the dataset has no entry for the option", {
  # MERFISH is selected but has no offset_x preset -> fallback.
  expect_equal(
    resolve("spatial_images_offset_x", 0, opts, crb_files, "merfish.crb"),
    0
  )
})

test_that("returns the fallback when the option is absent entirely", {
  expect_equal(
    resolve("spatial_images_scale_x", 1, opts, crb_files, "visium.crb"),
    1
  )
})

test_that("returns the fallback when nothing is selected", {
  expect_equal(
    resolve("spatial_images_offset_x", 0, opts, crb_files, NULL),
    0
  )
})

test_that("returns the fallback when the selected file is not among the files", {
  expect_equal(
    resolve("spatial_images_offset_x", 0, opts, crb_files, "unknown.crb"),
    0
  )
})

test_that("resolves logical presets and preserves their type", {
  expect_identical(
    resolve("spatial_images_flip_y", FALSE, opts, crb_files, "visium.crb"),
    TRUE
  )
})

test_that("returns the fallback for an NA preset value", {
  opts_na <- list(
    spatial_images_offset_x = c("Mouse brain (Visium)" = NA_real_)
  )
  expect_equal(
    resolve("spatial_images_offset_x", 7, opts_na, crb_files, "visium.crb"),
    7
  )
})

test_that("returns the fallback for a non-scalar preset value", {
  opts_vec <- list(
    spatial_images_offset_x = list("Mouse brain (Visium)" = c(1, 2))
  )
  expect_equal(
    resolve("spatial_images_offset_x", 3, opts_vec, crb_files, "visium.crb"),
    3
  )
})

test_that("returns the fallback when options is NULL", {
  expect_equal(
    resolve("spatial_images_offset_x", 0, NULL, crb_files, "visium.crb"),
    0
  )
})
