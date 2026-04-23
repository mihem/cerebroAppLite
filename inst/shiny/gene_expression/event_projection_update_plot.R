##----------------------------------------------------------------------------##
## Update projection plot when expression_projection_data_to_plot() changes.
##----------------------------------------------------------------------------##
observeEvent(expression_projection_data_to_plot(), {
  req(expression_projection_data_to_plot())
  # message('--> trigger update plot')
  expression_projection_parameters_other[['reset_axes']] <- FALSE
  withProgress(message = 'Updating gene expression projection...', value = 0.5, {
    expression_projection_update_plot(expression_projection_data_to_plot())
  })
  ## Mark tab as initialized after first successful plot update
  if (!gene_expression_initialized()) {
    gene_expression_initialized(TRUE)
  }
}, ignoreInit = FALSE)
