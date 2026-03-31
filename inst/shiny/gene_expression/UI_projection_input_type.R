##----------------------------------------------------------------------------##
## UI elements to choose whether gene(s) or gene sets should be analyzed
##----------------------------------------------------------------------------##
output[["expression_projection_input_type_UI"]] <- renderUI({
  req(input[["expression_analysis_mode"]])

  input_element <- NULL

  if ( input[["expression_analysis_mode"]] == "Gene(s)" ) {
    input_element <- selectizeInput(
      'expression_genes_input',
      label = 'Gene(s)',
      choices = NULL,
      options = list(
        maxOptions = 100,
        placeholder = 'Select a gene...',
        create = FALSE,
        loadThrottle = 30
      ),
      multiple = TRUE
    )
  } else if ( input[["expression_analysis_mode"]] == "Gene set" ) {
    input_element <- selectizeInput(
      'expression_select_gene_set',
      label = 'Gene set',
      choices = c("-", msigdbr:::msigdbr_genesets$gs_name),
      multiple = FALSE
    )
  }

  tagList(
    input_element,
    actionButton(
      inputId = "expression_projection_update_button",
      label = "Plot Expression",
      icon = icon("play"),
      style = "width: 100%; margin-top: 5px;",
      class = "btn-primary"
    )
  )
})

## update gene list on server side
observeEvent(input[["expression_analysis_mode"]], {
  req(input[["expression_analysis_mode"]] == "Gene(s)")
  updateSelectizeInput(
    session,
    'expression_genes_input',
    choices = getGeneNames(),
    server = TRUE
  )
})
