##----------------------------------------------------------------------------##
## HLA & TCR Motifs — descriptive feature x HLA overlap
##
## This tab freezes one node or motif from the already-built graph, then reports
## observed donor/sample overlap with one allele. It performs no enrichment test
## and never labels co-occurrence as restriction.
##----------------------------------------------------------------------------##

hla_feature_catalog <- reactive({
  g <- hla_motif_graph()
  if (!hla_motif_graph_ok(g)) {
    return(NULL)
  }
  va <- igraph::vertex_attr(g)
  data.frame(
    node_id = as.character(va$name),
    cdr3 = as.character(va$cdr3),
    v_gene = as.character(va$v_gene),
    motif_group = as.character(va$motif_group),
    stringsAsFactors = FALSE
  )
})

hla_selected_feature_members <- reactive({
  catalog <- hla_feature_catalog()
  if (is.null(catalog) || nrow(catalog) == 0) {
    return(NULL)
  }
  feature_type <- hla_param("hla_feature_type", "motif")
  feature_id <- input$hla_feature_id
  if (is.null(feature_id) || !nzchar(feature_id)) {
    return(NULL)
  }
  if (identical(feature_type, "node")) {
    catalog[catalog$node_id == feature_id, , drop = FALSE]
  } else {
    catalog[catalog$motif_group == feature_id, , drop = FALSE]
  }
})

output$hla_feature_selector_ui <- renderUI({
  catalog <- hla_feature_catalog()
  if (is.null(catalog) || nrow(catalog) == 0) {
    return(tags$p(class = "text-muted", "No drawable motif feature available."))
  }
  feature_type <- hla_param("hla_feature_type", "motif")
  if (identical(feature_type, "node")) {
    labels <- if (isTRUE(hla_param("hla_by_v", hla_by_v_default()))) {
      paste0(catalog$cdr3, " [", catalog$v_gene, "]")
    } else {
      catalog$cdr3
    }
    choices <- stats::setNames(catalog$node_id, labels)
  } else {
    # Largest motif first. Motif ids are generated in length-bin order, so the
    # natural order opens on an arbitrary two-CDR3 component; a bigger component
    # is the more informative thing to land on and rests on more observations.
    sizes <- table(catalog$motif_group)
    groups <- names(sort(sizes, decreasing = TRUE))
    labels <- sprintf("%s (%d CDR3)", groups, as.integer(sizes[groups]))
    choices <- stats::setNames(groups, labels)
  }
  selectInput("hla_feature_id", "Frozen feature:", choices = choices)
})

hla_overlap_table <- reactive({
  typing <- hla_active_typing()
  members <- hla_selected_feature_members()
  allele <- input$hla_association_allele
  seg <- hla_segments()
  if (
    !hla_has_typing() ||
      is.null(members) ||
      is.null(seg) ||
      is.null(allele) ||
      !nzchar(allele)
  ) {
    return(NULL)
  }
  hla_descriptive_feature_overlap(
    typing = typing,
    segments = seg,
    samples = names(getImmuneRepertoire()),
    allele = allele,
    feature_cdr3 = members$cdr3,
    feature_v_gene = if (isTRUE(hla_param("hla_by_v", hla_by_v_default()))) {
      members$v_gene
    } else {
      NULL
    }
  )
})

output$hla_associations_ui <- renderUI({
  if (!hla_has_typing()) {
    return(tags$p(
      class = "text-muted",
      paste(
        "No HLA typing loaded. Provide HLA typing in Data & QC to inspect",
        "feature-specific descriptive overlap."
      )
    ))
  }
  # Same labelling/order as the network's picker: an alphabetical list of every
  # allele makes the user guess which ones can show a contrast at all.
  alleles <- hla_allele_choices()
  tagList(
    # A circular selection is the one thing a reader cannot detect from the
    # numbers, so it is stated first and in the stronger style.
    if (!is.null(hla_selection_caveat())) {
      tags$div(
        class = "alert alert-warning",
        style = "font-size: 13px;",
        tags$b("Positive control - the contrast below is built in. "),
        hla_selection_caveat()
      )
    },
    tags$div(
      class = "alert alert-info",
      style = "font-size: 13px;",
      tags$b("Descriptive overlap only."),
      paste(
        "The selected node/motif is frozen from the current Hamming-1 graph.",
        "Counts are donor-level only with complete donor mapping, otherwise",
        "sample-level. No p-value or restriction claim is produced."
      )
    ),
    fluidRow(
      column(
        4,
        selectInput(
          "hla_association_allele",
          "HLA allele:",
          choices = alleles,
          selected = alleles[1]
        )
      ),
      column(
        3,
        radioButtons(
          "hla_feature_type",
          "Feature type:",
          choices = c("Motif component" = "motif", "CDR3 node" = "node"),
          selected = "motif",
          inline = TRUE
        )
      ),
      column(5, uiOutput("hla_feature_selector_ui"))
    ),
    tags$h4("Observed overlap summary"),
    DT::dataTableOutput("hla_overlap_summary"),
    tags$h4(sprintf(
      "Per-unit breadth and %s fraction",
      hla_unit_noun()
    )),
    # State the denominator. These are fractions of what this data set contains,
    # which is not the donor's repertoire whenever the receptors were selected
    # (see the positive-control notice above).
    tags$p(
      class = "text-muted",
      style = "font-size: 12px;",
      sprintf(
        paste(
          "Fractions are of the %ss and clonotypes present IN THIS DATA SET",
          "for each unit%s - not of the unit's full repertoire."
        ),
        hla_unit_noun(),
        if (!is.null(hla_selection_caveat())) {
          ", which holds a selected subset of receptors"
        } else {
          ""
        }
      )
    ),
    DT::dataTableOutput("hla_overlap_table"),
    tags$h4("Analysis-unit × HLA allele matrix"),
    tags$p(
      class = "text-muted",
      style = "font-size: 12px;",
      "1 = carrier, 0 = locus-typed non-carrier, blank = locus untyped."
    ),
    DT::dataTableOutput("hla_allele_matrix")
  )
})

output$hla_overlap_summary <- DT::renderDataTable({
  df <- hla_overlap_table()
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  statuses <- c("carrier", "non-carrier", "untyped")
  show <- do.call(
    rbind,
    lapply(statuses, function(status) {
      d <- df[df$hla_status == status, , drop = FALSE]
      data.frame(
        `HLA status` = status,
        `Analysis units` = nrow(d),
        `Units with feature` = sum(d$feature_present),
        `Observed feature prevalence` = if (nrow(d) > 0) {
          sprintf("%.1f%%", 100 * mean(d$feature_present))
        } else {
          "—"
        },
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    })
  )
  DT::datatable(show, rownames = FALSE, options = list(dom = "t"))
})

output$hla_overlap_table <- DT::renderDataTable({
  df <- hla_overlap_table()
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  show <- df
  show$unique_clonotype_fraction <- round(show$unique_clonotype_fraction, 4)
  show$cell_fraction <- round(show$cell_fraction, 4)
  # The core keeps neutral column names; the header names them for what this
  # data set actually holds, so bulk rows are never presented as cells.
  noun <- hla_unit_noun()
  headers <- colnames(show)
  headers[headers == "n_cells"] <- sprintf("n_%ss", noun)
  headers[headers == "n_feature_cells"] <- sprintf("n_feature_%ss", noun)
  headers[headers == "cell_fraction"] <- sprintf("%s_fraction", noun)
  DT::datatable(
    show,
    rownames = FALSE,
    colnames = headers,
    options = list(pageLength = 15, dom = "tip")
  )
})

output$hla_allele_matrix <- DT::renderDataTable({
  if (!hla_has_typing()) {
    return(NULL)
  }
  mat <- hla_unit_allele_matrix(
    hla_active_typing(),
    samples = names(getImmuneRepertoire())
  )
  DT::datatable(
    mat,
    rownames = FALSE,
    options = list(pageLength = 10, scrollX = TRUE, dom = "tip")
  )
})
