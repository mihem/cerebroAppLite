##----------------------------------------------------------------------------##
## Expression levels of cells in projection.
##----------------------------------------------------------------------------##
expression_projection_expression_levels <- reactive({
  req(
    expression_projection_cells_to_show()
  )
  input[["expression_projection_update_button"]]

  # message('--> trigger "expression_projection_expression_levels"')

  withProgress(message = 'Calculating expression levels...', value = 0.2, {
    cells_to_show <- expression_projection_cells_to_show()
    n_cells <- length(cells_to_show)
    genes_data <- isolate(expression_selected_genes())

    if ( length(genes_data$genes_to_display_present) == 0 ) {
      expression_levels <- rep(0, n_cells)
    } else {
      req(expression_projection_coordinates())
      if (
        ncol(expression_projection_coordinates()) == 2 &&
        input[["expression_projection_genes_in_separate_panels"]] == TRUE &&
        length(genes_data$genes_to_display_present) >= 2 &&
        length(genes_data$genes_to_display_present) <= 9
      ) {
        incProgress(0.3, detail = "Extracting matrix for multiple panels...")
        expression_matrix <- data_set()$expression[genes_data$genes_to_display_present, , drop=FALSE]
        expression_matrix <- Matrix::t(expression_matrix)
        expression_levels <- list()
        for (i in 1:ncol(expression_matrix)) {
          expression_levels[[colnames(expression_matrix)[i]]] <- as.vector(expression_matrix[,i])
        }
      } else if (length(genes_data$genes_to_display_present) == 1) {
        incProgress(0.3, detail = "Extracting single gene expression...")
        expression_levels <- data_set()$expression[genes_data$genes_to_display_present,]
        if(is.numeric(expression_levels)) {
          expression_levels <- unname(expression_levels)
        }
        if (is(expression_levels, "IterableMatrix")) {
        expression_levels <- as.numeric(as(expression_levels, "matrix"))
        }
        expression_levels <- expression_levels[cells_to_show]
      } else if (length(genes_data$genes_to_display_present) >= 2) {
        incProgress(0.3, detail = "Calculating mean expression...")
        expression_levels <- data_set()$expression[genes_data$genes_to_display_present,]
        if (inherits(expression_levels, "Matrix") || inherits(expression_levels, "dgCMatrix")) {
          expression_levels <- Matrix::colMeans(expression_levels)
        } else {
          expression_levels <- colMeans(as.matrix(expression_levels))
        }
        expression_levels <- unname(expression_levels)
        expression_levels <- expression_levels[cells_to_show]
      }
    }
    # message(str(expression_levels))
    return(expression_levels)
  })
})
