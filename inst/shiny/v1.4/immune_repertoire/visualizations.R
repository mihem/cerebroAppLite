  ## ---- Minimal settings UI ---------------------------------------------- ##
  output$ir_settings_UI <- renderUI({
    req(has_scRepertoire())
    raw <- ir_data_raw()
    if (is.null(raw)) {
      return(div(class = "alert alert-warning",
        "No immune repertoire data available. Import data with TCR/BCR annotations first."))
    }

    fluidRow(
      column(4, selectInput("ir_cloneCall", "Clone call:",
        choices = c("gene", "nt", "aa", "strict"), selected = "gene")),
      column(4, selectInput("ir_chain", "Chain:",
        choices = c("All" = "both"), selected = "both"))
    )
  })

  output$ir_help_panel <- renderUI(NULL)

  ## ---- Visualizations UI ------------------------------------------------ ##
  output$ir_visualizations_UI <- renderUI({
    req(has_scRepertoire())
    data <- ir_data()
    if (is.null(data)) {
      return(div(class = "alert alert-warning",
        "No immune repertoire data available."))
    }

    tabsetPanel(
      id = "ir_tabs",
      tabPanel("Abundance",
        shinycssloaders::withSpinner(plotOutput("ir_plot_clonalAbundance", height = 450)))
    )
  })

  output$ir_plot_clonalAbundance <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalAbundance(data, cloneCall = pars$cloneCall,
        group.by = pars$groupBy),
      "clonalAbundance")
  })
