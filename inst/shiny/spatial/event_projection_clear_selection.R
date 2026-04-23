##----------------------------------------------------------------------------##
## Clear selection button event handler.
##----------------------------------------------------------------------------##
observeEvent(input[["spatial_projection_clear_selection"]], {
  ## Call JavaScript function to clear the plotly selection
  shinyjs::js$spatialClearSelection()
})
