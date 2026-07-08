##----------------------------------------------------------------------------##
## UI elements to select X and Y limits in projection.
##----------------------------------------------------------------------------##
output[["spatial_projection_scales_UI"]] <- renderUI({
  if (
    is.null(input[["spatial_projection_to_display"]]) ||
      is.na(input[["spatial_projection_to_display"]]) ||
      input[["spatial_projection_to_display"]] %in% availableSpatial() == FALSE
  ) {
    projection_to_display <- availableSpatial()[1]
  } else {
    projection_to_display <- input[["spatial_projection_to_display"]]
  }
  ##
  spatial_data <- getSpatialData(projection_to_display)
  co <- spatial_data$coordinates
  ## Spatial coordinates are large positive values (pixels / microns), so the
  ## generic getXYranges() multiplicative padding (min*0.9, max*1.1) produces a
  ## badly ASYMMETRIC frame — the top/right whitespace ends up many times the
  ## bottom/left. Use a SYMMETRIC additive margin (2% of each axis span) so the
  ## default view sits evenly framed. The slider bounds are widened to give room
  ## to drag beyond the data.
  x_rng <- range(co[[1]], na.rm = TRUE)
  y_rng <- range(co[[2]], na.rm = TRUE)
  x_mar <- diff(x_rng) * 0.02
  y_mar <- diff(y_rng) * 0.02
  x_lo <- round(x_rng[1] - x_mar)
  x_hi <- round(x_rng[2] + x_mar)
  y_lo <- round(y_rng[1] - y_mar)
  y_hi <- round(y_rng[2] + y_mar)
  ##
  tagList(
    sliderInput(
      "spatial_projection_scale_x_manual_range",
      label = "Range of X axis",
      min = round(x_rng[1] - diff(x_rng) * 0.2),
      max = round(x_rng[2] + diff(x_rng) * 0.2),
      value = c(x_lo, x_hi)
    ),
    sliderInput(
      "spatial_projection_scale_y_manual_range",
      label = "Range of Y axis",
      min = round(y_rng[1] - diff(y_rng) * 0.2),
      max = round(y_rng[2] + diff(y_rng) * 0.2),
      value = c(y_lo, y_hi)
    )
  )
})

## make sure elements are loaded even though the box is collapsed
outputOptions(
  output,
  "spatial_projection_scales_UI",
  suspendWhenHidden = FALSE
)
