## ---- Settings UI ------------------------------------------------------ ##
output$ir_settings_UI <- renderUI({
  if (!has_scRepertoire()) {
    return(ir_scRepertoire_missing_ui())
  }
  raw <- ir_data_raw()
  if (is.null(raw)) {
    return(div(
      class = "alert alert-warning",
      "No immune repertoire data available. Import data with TCR/BCR annotations first."
    ))
  }

  chains_present <- detect_chains(raw)
  tcr_present <- intersect(chains_present, c("TRA", "TRB", "TRG", "TRD"))
  bcr_present <- intersect(chains_present, c("IGH", "IGK", "IGL"))
  # Build a flat named vector of chain choices. A nested list mixing a
  # top-level scalar ("both") with sub-lists (TCR/BCR optgroups) renders
  # incorrectly under selectize (only the scalar survives), so keep it flat.
  chain_choices <- c("All chains" = "both")
  if (length(tcr_present) > 0) {
    chain_choices <- c(chain_choices, setNames(tcr_present, tcr_present))
  }
  if (length(bcr_present) > 0) {
    chain_choices <- c(chain_choices, setNames(bcr_present, bcr_present))
  }

  # Grouping options come from the data set's declared grouping variables
  # joined onto the IR data by barcode (see ir_data_annotated), so users can
  # group by ANY metadata column (sample, condition, treatment, cell type, ...)
  # rather than only columns embedded in the IR table itself.
  annotated <- ir_data_annotated()
  data_cols <- if (!is.null(annotated)) {
    names(annotated[[1]])
  } else {
    names(raw[[1]])
  }
  groups <- tryCatch(getGroups(), error = function(e) character(0))
  available_groups <- intersect(groups, data_cols)

  # Which tabs each global control does NOT apply to (so it is omitted, not
  # left as an empty grid cell). Server-side filtering keeps the layout compact.
  tab <- input$ir_tabs
  clonecall_hidden <- c(
    "Isotype",
    "SHM Proxy",
    "Gene usage",
    "vizGenes",
    "percentGenes",
    "percentVJ",
    "AA %",
    "Entropy",
    "Property"
  )
  # Clonal UMAP uses its own Receptor selector instead of the global Chain, and
  # colours by clone size rather than a group.by split, so hide both there.
  groupby_hidden <- c("Paired Scatter", "Clonal UMAP")
  chain_hidden <- c("vizGenes", "Clonal UMAP")

  # Collect only the controls that apply to the current tab, then flow them into
  # rows so a hidden control never leaves a blank gap.
  controls <- list()
  if (is.null(tab) || !(tab %in% clonecall_hidden)) {
    controls <- c(
      controls,
      list(selectInput(
        "ir_cloneCall",
        "Clone call:",
        choices = c("gene", "nt", "aa", "strict"),
        selected = "gene",
        selectize = FALSE
      ))
    )
  }
  if (is.null(tab) || !(tab %in% chain_hidden)) {
    controls <- c(
      controls,
      list(selectInput(
        "ir_chain",
        "Chain:",
        choices = chain_choices,
        selected = "both",
        selectize = FALSE
      ))
    )
  }
  if (is.null(tab) || !(tab %in% groupby_hidden)) {
    # Default to the first available grouping variable (generic — NOT hardcoded
    # to "sample", since a data set may not have a "sample" column) so the
    # control reflects the grouping the plot actually uses. None still means
    # "group by list element". Preserve the user's choice across tab switches.
    prev_gb <- isolate(input$ir_groupBy)
    default_gb <- if (!is.null(prev_gb)) {
      prev_gb
    } else if (length(available_groups) > 0) {
      available_groups[1]
    } else {
      ""
    }
    controls <- c(
      controls,
      list(selectInput(
        "ir_groupBy",
        "Group by:",
        choices = c("None" = "", available_groups),
        selected = default_gb,
        selectize = FALSE
      ))
    )
  }

  tagList(
    tags$style(
      "#ir_chain + .selectize-control .selectize-dropdown-content { max-height: none; }"
    ),
    # Global controls, flowed two-per-row so no hidden control leaves a gap.
    ir_flow_controls(controls),
    helpText(
      tags$b("Group by"),
      "is the scRepertoire grouping variable: it splits the repertoire by a",
      "metadata column (sample, condition, cell type, ...). It defaults to the",
      "first available grouping variable; \"None\" groups by list element."
    ),
    # Function-specific analysis parameters (IR_PARAM_SPEC for the current tab).
    uiOutput("ir_param_panel"),
    # Generic display options (font/title, scatter point size/opacity),
    # collapsible so they don't crowd the panel.
    uiOutput("ir_display_panel"),
    # Scatter / Compare sample selectors only on their own tabs.
    conditionalPanel(
      condition = "input.ir_tabs == 'Scatter'",
      uiOutput("ir_scatter_settings")
    ),
    conditionalPanel(
      condition = "input.ir_tabs == 'Compare'",
      uiOutput("ir_compare_settings")
    )
  )
})

## ---- Helper: flow a list of controls into rows (2 per row) ------------ ##
## Renders only the supplied (visible) controls, packed two per fluidRow, so a
## hidden control never leaves an empty grid cell.
ir_flow_controls <- function(controls) {
  controls <- Filter(Negate(is.null), controls)
  if (length(controls) == 0) {
    return(NULL)
  }
  rows <- list()
  i <- 1
  while (i <= length(controls)) {
    if (i + 1 <= length(controls)) {
      rows[[length(rows) + 1]] <- fluidRow(
        column(6, controls[[i]]),
        column(6, controls[[i + 1]])
      )
      i <- i + 2
    } else {
      rows[[length(rows) + 1]] <- fluidRow(column(6, controls[[i]]))
      i <- i + 1
    }
  }
  do.call(tagList, rows)
}

## ---- Scatter sample selectors (Scatter tab only) --------------------- ##
output$ir_scatter_settings <- renderUI({
  available_samples <- ir_compare_groups()
  if (length(available_samples) < 2) {
    return(helpText(
      "Clonal scatter compares two groups. Use 'Group by' above to",
      "divide the data into at least two groups."
    ))
  }
  fluidRow(
    column(
      6,
      # selectize = FALSE: see ir_chain — selectize widgets rendered inside a
      # hidden conditionalPanel drop all but the selected option.
      selectInput(
        "ir_scatter_x",
        "Scatter: X axis",
        choices = available_samples,
        selected = available_samples[1],
        selectize = FALSE
      )
    ),
    column(
      6,
      selectInput(
        "ir_scatter_y",
        "Scatter: Y axis",
        choices = available_samples,
        selected = available_samples[2],
        selectize = FALSE
      )
    )
  )
})

## ---- Compare sample selector (Compare tab only) ---------------------- ##
output$ir_compare_settings <- renderUI({
  available_samples <- ir_compare_groups()
  if (length(available_samples) < 2) {
    return(helpText(
      "Clonal comparison needs at least two groups. Use 'Group by'",
      "above to divide the data."
    ))
  }
  fluidRow(
    column(
      12,
      # selectize = FALSE (native multi-select listbox): a multiple selectize
      # inside a hidden conditionalPanel keeps only the pre-selected items and
      # drops the rest of the available groups.
      selectInput(
        "ir_compare_samples",
        "Groups to compare (select >= 2):",
        choices = available_samples,
        multiple = TRUE,
        selected = available_samples[1:min(2, length(available_samples))],
        selectize = FALSE
      )
    )
  )
})

## ---- Available gene-segment families (for vizGenes x.axis) ------------ ##
ir_gene_families <- reactive({
  raw <- ir_data_raw()
  fams <- c(
    "TRAV",
    "TRAJ",
    "TRBV",
    "TRBD",
    "TRBJ",
    "TRGV",
    "TRGJ",
    "TRDV",
    "TRDJ",
    "IGHV",
    "IGHD",
    "IGHJ",
    "IGKV",
    "IGKJ",
    "IGLV",
    "IGLJ"
  )
  if (is.null(raw)) {
    return(fams)
  }
  all_ct <- paste(unlist(lapply(raw, function(d) d$CTgene)), collapse = ";")
  present <- fams[vapply(fams, function(f) grepl(f, all_ct), logical(1))]
  if (length(present) == 0) fams else present
})

## ---- Function-specific parameter panel (driven by IR_PARAM_SPEC) ------ ##
## Renders exactly the analysis-parameter controls of the current tab's
## scRepertoire function. Dynamic choice tokens are resolved here; all selects
## use selectize = FALSE (selectize drops options in hidden/dynamic UI).
output$ir_param_panel <- renderUI({
  tab <- input$ir_tabs
  if (
    is.null(tab) || !exists("IR_PARAM_SPEC") || is.null(IR_PARAM_SPEC[[tab]])
  ) {
    return(NULL)
  }
  spec <- IR_PARAM_SPEC[[tab]]

  groups <- tryCatch(getGroups(), error = function(e) character(0))
  genes <- ir_gene_families()

  controls <- lapply(spec, function(p) {
    if (identical(p$type, "numeric")) {
      return(numericInput(
        p$id,
        p$label,
        value = p$value,
        min = p$min,
        max = p$max,
        step = p$step
      ))
    }
    if (identical(p$type, "checkbox")) {
      return(checkboxInput(p$id, p$label, value = isTRUE(p$value)))
    }
    if (identical(p$type, "text")) {
      return(textInput(p$id, p$label, value = p$value))
    }
    # select
    choices <- p$choices
    selected <- p$value
    if (identical(choices, "<<groups>>")) {
      choices <- c("None" = "", groups)
    } else if (identical(choices, "<<genes>>")) {
      choices <- genes
    } else if (identical(choices, "<<property_methods>>")) {
      # detected at runtime (immApex availability)
      choices <- names(available_property_methods())
      if (is.null(selected) || !selected %in% choices) {
        selected <- choices[1]
      }
    } else if (identical(choices, "<<receptors>>")) {
      # TCR / BCR — only the receptor classes present in the data.
      choices <- ir_receptor_types()
      if (is.null(selected) || !selected %in% choices) {
        selected <- if (length(choices) > 0) choices[1] else NULL
      }
    } else if (identical(choices, "<<projections>>")) {
      # cell projections (UMAP/tSNE) available in the data set; default first.
      choices <- tryCatch(availableProjections(), error = function(e) {
        character(0)
      })
      if (is.null(selected) || !selected %in% choices) {
        selected <- if (length(choices) > 0) choices[1] else NULL
      }
    }
    selectInput(
      p$id,
      p$label,
      choices = choices,
      selected = selected,
      selectize = FALSE
    )
  })

  # two controls per row
  rows <- list()
  i <- 1
  while (i <= length(controls)) {
    if (i + 1 <= length(controls)) {
      rows[[length(rows) + 1]] <- fluidRow(
        column(6, controls[[i]]),
        column(6, controls[[i + 1]])
      )
      i <- i + 2
    } else {
      rows[[length(rows) + 1]] <- fluidRow(column(6, controls[[i]]))
      i <- i + 1
    }
  }
  do.call(tagList, rows)
})

## ---- Reactive: number of samples -------------------------------------- ##
n_samples <- reactive({
  data <- ir_data()
  if (is.null(data)) 0L else length(data)
})

## ---- Generic display options (collapsible) ---------------------------- ##
## Renders the IR_DISPLAY_SPEC controls applicable to the current tab inside a
## collapsible <details> block, kept separate from the analysis params so the
## panel stays compact. Defaults collapsed (no `open` attribute).
output$ir_display_panel <- renderUI({
  tab <- input$ir_tabs
  if (!exists("ir_display_params_for")) {
    return(NULL)
  }
  spec <- ir_display_params_for(tab)
  if (length(spec) == 0) {
    return(NULL)
  }

  controls <- lapply(spec, function(p) {
    if (identical(p$type, "numeric")) {
      return(numericInput(
        p$id,
        p$label,
        value = p$value,
        min = p$min,
        max = p$max,
        step = p$step
      ))
    }
    # text (the only other display type)
    textInput(p$id, p$label, value = p$value)
  })

  # two controls per row
  rows <- list()
  i <- 1
  while (i <= length(controls)) {
    if (i + 1 <= length(controls)) {
      rows[[length(rows) + 1]] <- fluidRow(
        column(6, controls[[i]]),
        column(6, controls[[i + 1]])
      )
      i <- i + 2
    } else {
      rows[[length(rows) + 1]] <- fluidRow(column(6, controls[[i]]))
      i <- i + 1
    }
  }

  tags$details(
    id = "ir_display_details",
    tags$summary(tags$b("Display options")),
    do.call(tagList, rows)
  )
})

## ---- Reactive: current display parameter values ----------------------- ##
## Collects the live display-control values for the current tab, falling back
## to each param's declared default when the input is absent (e.g. a control
## not rendered on the current tab). Consumed by ir_apply_display().
ir_display_params <- reactive({
  tab <- input$ir_tabs
  spec <- if (exists("ir_display_params_for")) {
    ir_display_params_for(tab)
  } else {
    list()
  }
  vals <- list()
  for (p in spec) {
    v <- input[[p$id]]
    vals[[p$id]] <- if (
      is.null(v) || (is.character(v) && !nzchar(v) && p$type != "text")
    ) {
      p$value
    } else {
      v
    }
  }
  vals
})
