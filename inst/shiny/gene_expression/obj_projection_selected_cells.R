##----------------------------------------------------------------------------##
## Reactive that holds IDs of selected cells (ID is built from position in
## projection).
##----------------------------------------------------------------------------##
expression_projection_selected_cells <- reactive({
  ## make sure plot parameters are set because it means that the plot can be
  ## generated
  req(
    expression_projection_parameters_plot(),
    expression_projection_data()
  )

  ## DEBUG: Print raw event data
  raw_event <- plotly::event_data("plotly_selected", source = "expression_projection")
  message("=== DEBUG: expression_projection_selected_cells ===")
  message("  Raw event_data is NULL: ", is.null(raw_event))
  message("  Raw event_data length: ", length(raw_event))

  ## check selection
  ## ... selection has not been made or there is no cell in it
  if (
    is.null(raw_event) ||
    length(raw_event) == 0
  ) {
    message("  --> Returning NULL (no selection)")
    return(NULL)
  ## ... selection has been made and at least 1 cell is in it
  } else {
    ## get number of selected cells
    selected_cells <- raw_event %>%
      dplyr::mutate(identifier = paste0(x, '-', y))
    message("  --> Returning ", nrow(selected_cells), " selected cells")
    return(selected_cells)
  }
})
