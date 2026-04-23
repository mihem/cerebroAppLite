##----------------------------------------------------------------------------##
## Coordinates of cells in projection.
##----------------------------------------------------------------------------##
overview_projection_coordinates <- reactive({
  req(
    overview_projection_parameters_plot(),
    overview_projection_cells_to_show()
  )
  # message('--> trigger "overview_projection_coordinates"')
  parameters <- overview_projection_parameters_plot()
  indices <- overview_projection_cells_to_show()
  
  req(parameters[["projection"]] %in% availableProjections())
  
  ## Optimization: Handle empty indices case
  if (length(indices) == 0) {
     return(getProjection(parameters[["projection"]])[0, , drop = FALSE])
  }
  
  coordinates <- getProjection(parameters[["projection"]])[indices, , drop = FALSE]
#   message(str(coordinates))
  return(coordinates)
})
