##----------------------------------------------------------------------------##
## Object that combines all data required for updating projection plot.
## OPTIMIZED: Consolidated debouncing (150ms) and inlined hover_info logic.
##----------------------------------------------------------------------------##
expression_projection_data_to_plot_raw <- reactive({
  req(
    expression_projection_coordinates(),
    expression_projection_parameters_plot(),
    expression_projection_parameters_color(),
    expression_projection_trajectory(),
    nrow(expression_projection_coordinates()) == length(isolate(expression_projection_expression_levels())) ||
    nrow(expression_projection_coordinates()) == length(isolate(expression_projection_expression_levels())[[1]]),
    !is.null(input[["expression_projection_genes_in_separate_panels"]])
  )
  # message('--> trigger "expression_projection_data_to_plot"')
  parameters <- expression_projection_parameters_plot()
  cells_to_show <- isolate(expression_projection_cells_to_show())

  if (parameters[['is_trajectory']]) {
    req(nrow(expression_projection_coordinates()) ==
      nrow(expression_projection_trajectory()[['meta']]))
  }

  ## Inline hover_info logic (previously in separate reactive)
  if (
    !is.null(preferences[["show_hover_info_in_projections"]]) &&
    preferences[['show_hover_info_in_projections']] == TRUE
  ) {
    hover_info <- hover_info_projections()[cells_to_show]
  } else {
    hover_info <- hover_info_projections()
  }
  req(
    nrow(expression_projection_coordinates()) == length(hover_info) ||
    hover_info[1] == "none" ||
    length(hover_info) == 1
  )

  to_return <- list(
    coordinates = expression_projection_coordinates(),
    reset_axes = isolate(expression_projection_parameters_other[['reset_axes']]),
    ## use isolate() to avoid updating before new color range is calculated
    expression_levels = isolate(expression_projection_expression_levels()),
    plot_parameters = expression_projection_parameters_plot(),
    color_settings = expression_projection_parameters_color(),
    hover_info = hover_info,
    trajectory = expression_projection_trajectory(),
    separate_panels = input[["expression_projection_genes_in_separate_panels"]]
  )
  # message(str(to_return))
  return(to_return)
})

## Single debounce point for all plot updates (150ms)
expression_projection_data_to_plot <- debounce(expression_projection_data_to_plot_raw, 150)
