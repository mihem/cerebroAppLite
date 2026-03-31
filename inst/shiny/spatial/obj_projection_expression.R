##----------------------------------------------------------------------------##
## Cell meta data and position in projection.
##----------------------------------------------------------------------------##
spatial_projection_expression <- reactive({
  req(
    spatial_projection_parameters_plot(),
    spatial_projection_cells_to_show()
  )

  parameters    <- spatial_projection_parameters_plot()
  cells_to_show <- spatial_projection_cells_to_show()
  req(parameters[["projection"]] %in% availableProjections())
  return(NULL)
})
