##----------------------------------------------------------------------------##
## Clear selection button event handler.
##----------------------------------------------------------------------------##
observeEvent(input[["overview_projection_clear_selection"]], {
  ## Call JavaScript function to clear the plotly selection
  shinyjs::js$overviewClearSelection()
})
