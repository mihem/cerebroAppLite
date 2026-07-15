##----------------------------------------------------------------------------##
## HLA & TCR Motifs — parameter + status panels
##----------------------------------------------------------------------------##

## ---- Left-column parameters ------------------------------------------- ##
output$hla_parameters_ui <- renderUI({
  chains <- hla_tcr_chains()
  meta_cols <- hla_usable_color_cols()
  color_choices <- c(
    "Motif cluster" = "",
    stats::setNames(meta_cols, meta_cols)
  )
  # "MHC context" is a derived node attribute (CD8->Class I / CD4->Class II /
  # Unknown), offered only when a cell-type column exists to derive it from.
  if (!is.na(hla_celltype_col())) {
    color_choices <- c(color_choices, "MHC context" = "mhc_context")
  }
  # Carrier status of ONE allele is the colouring this page exists for: it is
  # what connects the network to the HLA context. Offered only with typing, and
  # deliberately named for what it shows (who carries the allele), never as if
  # the allele restricted the TCR.
  if (hla_has_typing()) {
    color_choices <- c(
      color_choices,
      "HLA carrier status (pick allele below)" = "hla_carrier"
    )
  }
  tagList(
    if (length(chains) > 1) {
      selectInput(
        "hla_chain",
        "Chain:",
        choices = chains,
        selected = hla_active_chain()
      )
    } else {
      tags$p(
        tags$b("Chain: "),
        if (length(chains) == 1) chains[1] else "none"
      )
    },
    selectInput(
      "hla_color_by",
      "Colour nodes by:",
      choices = color_choices,
      selected = hla_param("hla_color_by", "")
    ),
    # The allele whose carrier status colours the network. Only meaningful for
    # the carrier colouring, so it is shown only then. Changing it re-colours
    # from the cached graph; it never rebuilds the Hamming distance matrix.
    conditionalPanel(
      condition = "input.hla_color_by == 'hla_carrier'",
      uiOutput("hla_color_allele_ui")
    ),
    sliderInput(
      "hla_min_nodes",
      "Minimum motif size (nodes):",
      min = 2,
      max = 10,
      value = hla_default_min_nodes(),
      step = 1
    ),
    checkboxInput(
      "hla_by_v",
      "Split motifs by V gene",
      value = isTRUE(hla_param("hla_by_v", hla_by_v_default()))
    ),
    checkboxInput(
      "hla_show_isolated",
      "Show unconnected CDR3s",
      value = isTRUE(hla_param("hla_show_isolated", FALSE))
    ),
    tags$p(
      class = "text-muted",
      style = "font-size: 11px;",
      "Edges use Hamming distance 1 (fixed)."
    )
  )
})

## ---- Allele picker for carrier colouring ------------------------------ ##
## Labelled with the carrier split and ordered by informativeness, so the user
## is not choosing blind out of a long alphabetical list: an allele that only
## one sample carries cannot show a contrast, and an allele nobody lacks cannot
## either. See hla_allele_choices() in data.R.
output$hla_color_allele_ui <- renderUI({
  choices <- hla_allele_choices()
  if (length(choices) == 0) {
    return(tags$p(class = "text-muted", "No HLA alleles available."))
  }
  selectInput(
    "hla_color_allele",
    "HLA allele to colour by:",
    choices = choices,
    selected = hla_param("hla_color_allele", unname(choices[1]))
  )
})

## ---- Evidence-status panel -------------------------------------------- ##
output$hla_status_ui <- renderUI({
  t <- hla_active_typing()
  n_ir_samples <- length(getImmuneRepertoire())
  session_on <- !is.null(hla_session_typing()) &&
    is.data.frame(hla_session_typing()) &&
    nrow(hla_session_typing()) > 0
  channel <- if (session_on) "session upload" else "stored .crb"

  if (!hla_has_typing()) {
    return(tagList(
      tags$p(tags$b("HLA context: "), "none loaded"),
      tags$p(
        class = "text-muted",
        style = "font-size: 12px;",
        paste(
          "Motif network uses cell-type / sample colouring only. Provide HLA",
          "typing in the Data & QC tab to enable donor-level HLA context."
        )
      )
    ))
  }

  typed_samples <- length(unique(t$sample))
  src <- paste(unique(t$source_type), collapse = ", ")
  ir_samples <- names(getImmuneRepertoire())
  covered <- sum(ir_samples %in% unique(t$sample))
  tagList(
    tags$p(
      tags$b("HLA context source: "),
      channel,
      sprintf(" (%s)", src)
    ),
    tags$p(sprintf(
      "Coverage: %d / %d IR samples typed.",
      covered,
      n_ir_samples
    )),
    if (any(t$source_type %in% c("synthetic", "unknown"))) {
      tags$p(
        class = "text-warning",
        style = "font-size: 12px;",
        "Contains synthetic / unknown-provenance typing: descriptive context only."
      )
    },
    tags$p(
      class = "text-muted",
      style = "font-size: 12px;",
      paste(
        "Alleles shown for a motif are candidate co-occurrences, not confirmed",
        "TCR restrictions."
      )
    )
  )
})
