##----------------------------------------------------------------------------##
## Clear selection button event handler.
##----------------------------------------------------------------------------##
observeEvent(input[["expression_projection_clear_selection"]], {
  ## Call JavaScript function to clear the plotly selection
  shinyjs::js$expressionProjectionClearSelection()
})

##----------------------------------------------------------------------------##
## Toggle visibility of clear selection button.
##----------------------------------------------------------------------------##
observe({
  req(expression_projection_data_to_plot())

  if (
    !is.null(plotly::event_data("plotly_selected", source = "expression_projection")) &&
    length(plotly::event_data("plotly_selected", source = "expression_projection")) > 0
  ) {
    shinyjs::show("expression_projection_clear_selection")
  } else {
    shinyjs::hide("expression_projection_clear_selection")
  }
})
