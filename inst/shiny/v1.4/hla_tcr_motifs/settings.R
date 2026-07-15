##----------------------------------------------------------------------------##
## HLA & TCR Motifs — parameter + status panels
##----------------------------------------------------------------------------##

## ---- Left-column parameters ------------------------------------------- ##
output$hla_parameters_ui <- renderUI({
  chains <- hla_tcr_chains()
  color_choices <- c(
    "Motif cluster" = "",
    stats::setNames(hla_color_meta_cols(), hla_color_meta_cols())
  )
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
    sliderInput(
      "hla_min_nodes",
      "Minimum motif size (nodes):",
      min = 2,
      max = 10,
      value = as.integer(hla_param("hla_min_nodes", 2L)),
      step = 1
    ),
    checkboxInput(
      "hla_by_v",
      "Split motifs by V gene",
      value = isTRUE(hla_param("hla_by_v", FALSE))
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
