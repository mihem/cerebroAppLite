test_that("categorical colours stay unique beyond the base palette length", {
  levels <- paste0("level_", seq_len(25))

  colours <- hla_distinct_colors(levels)

  expect_equal(names(colours), levels)
  expect_length(unique(unname(colours)), length(levels))
})

test_that("empty colour levels return an empty named vector", {
  expect_equal(
    hla_distinct_colors(character(0)),
    stats::setNames(character(0), character(0))
  )
})
