# test-spatial-preset-codegen.R — unit tests for turning a hand-tuned overlay
# alignment into pasteable Cerebro.options preset code.
#
# After a user nudges the histology overlay into place in the Spatial tab, they
# need those numbers as `spatial_images_*` presets in app.R so the demo opens
# pre-aligned. This generator produces that snippet from the current control
# values for the current dataset label. It emits only the six supported options
# (offset_x/y, scale_x/y, flip_x/y) and only the non-identity ones, so a clean
# alignment yields a short snippet.

codegen <- cerebroAppLite:::format_spatial_preset_code

test_that("emits every non-identity option keyed by the dataset label", {
  out <- codegen(
    label = "Mouse brain (Visium)",
    offset_x = 500,
    offset_y = -1000,
    scale_x = 1.55,
    scale_y = 1.55,
    flip_x = FALSE,
    flip_y = TRUE
  )
  expect_true(grepl(
    '"spatial_images_offset_x" = c("Mouse brain (Visium)" = 500)',
    out,
    fixed = TRUE
  ))
  expect_true(grepl(
    '"spatial_images_offset_y" = c("Mouse brain (Visium)" = -1000)',
    out,
    fixed = TRUE
  ))
  expect_true(grepl(
    '"spatial_images_scale_x" = c("Mouse brain (Visium)" = 1.55)',
    out,
    fixed = TRUE
  ))
  expect_true(grepl(
    '"spatial_images_scale_y" = c("Mouse brain (Visium)" = 1.55)',
    out,
    fixed = TRUE
  ))
  expect_true(grepl(
    '"spatial_images_flip_y" = c("Mouse brain (Visium)" = TRUE)',
    out,
    fixed = TRUE
  ))
})

test_that("omits identity values (offset 0, scale 1, flip FALSE)", {
  out <- codegen(
    label = "X",
    offset_x = 0,
    offset_y = 0,
    scale_x = 1,
    scale_y = 1,
    flip_x = FALSE,
    flip_y = FALSE
  )
  expect_false(grepl("spatial_images_offset_x", out, fixed = TRUE))
  expect_false(grepl("spatial_images_scale_x", out, fixed = TRUE))
  expect_false(grepl("spatial_images_flip", out, fixed = TRUE))
})

test_that("a fully-identity alignment yields a clear 'nothing to persist' note", {
  out <- codegen(
    label = "X",
    offset_x = 0,
    offset_y = 0,
    scale_x = 1,
    scale_y = 1,
    flip_x = FALSE,
    flip_y = FALSE
  )
  expect_match(out, "no adjustments", ignore.case = TRUE)
})

test_that("emits only the axis that differs from identity", {
  out <- codegen(
    label = "X",
    offset_x = 42,
    offset_y = 0,
    scale_x = 1,
    scale_y = 1,
    flip_x = FALSE,
    flip_y = FALSE
  )
  expect_true(grepl(
    '"spatial_images_offset_x" = c("X" = 42)',
    out,
    fixed = TRUE
  ))
  expect_false(grepl("spatial_images_offset_y", out, fixed = TRUE))
})

test_that("emits flip_x TRUE when horizontally flipped", {
  out <- codegen(
    label = "X",
    offset_x = 0,
    offset_y = 0,
    scale_x = 1,
    scale_y = 1,
    flip_x = TRUE,
    flip_y = FALSE
  )
  expect_true(grepl(
    '"spatial_images_flip_x" = c("X" = TRUE)',
    out,
    fixed = TRUE
  ))
})

test_that("quotes a label containing special characters verbatim", {
  out <- codegen(
    label = "Mouse ileum (MERFISH)",
    offset_x = -350,
    offset_y = 0,
    scale_x = 1,
    scale_y = 1,
    flip_x = FALSE,
    flip_y = FALSE
  )
  expect_true(grepl('c("Mouse ileum (MERFISH)" = -350)', out, fixed = TRUE))
})
