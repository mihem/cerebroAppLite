##----------------------------------------------------------------------------##
## Coordinates of cells in projection.
##----------------------------------------------------------------------------##
spatial_projection_coordinates <- reactive({
  req(
    spatial_projection_parameters_plot(),
    spatial_projection_cells_to_show()
  )

  parameters    <- spatial_projection_parameters_plot()
  cells_to_show <- spatial_projection_cells_to_show()
  req(parameters[["projection"]] %in% availableSpatial())

  message("[debug] projection = ", parameters[["projection"]])

  spatial_data <- getSpatialData(parameters[["projection"]])
  coordinates <- spatial_data$coordinates[cells_to_show, , drop = FALSE]

  message("[debug] coordinates = ", head(coordinates))

  return(coordinates)
})
