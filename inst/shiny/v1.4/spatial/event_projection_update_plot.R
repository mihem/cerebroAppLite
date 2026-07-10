##----------------------------------------------------------------------------##
## Update projection plot when spatial_projection_data_to_plot() changes.
##----------------------------------------------------------------------------##

observeEvent(spatial_projection_data_to_plot(), {
  req(spatial_projection_data_to_plot())

  withProgress(message = 'Updating spatial plot...', value = 0.5, {
    data <- spatial_projection_data_to_plot()
    message(
      "[spatial] plot update triggered, background_image = ",
      data[['plot_parameters']][['background_image']]
    )
    spatial_projection_update_plot(data)
  })
})
