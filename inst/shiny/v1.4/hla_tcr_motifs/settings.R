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
  # Sample of origin, with every CDR3 seen in >1 sample collapsed to "Shared".
  # Distinct from colouring by the plain `sample` column, which shows the node's
  # MODAL sample and so hides the cross-sample recurrence an HLA screen looks
  # for. Offered only when the repertoire actually has more than one sample.
  if (length(names(getImmuneRepertoire())) > 1) {
    color_choices <- c(
      color_choices,
      "Sample of origin (shared = black)" = "sample_origin"
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
    # Scope decides WHICH CELLS the graph is built from; colour only decides how
    # the built graph is painted. Offered only with typing, since both scopes
    # other than "all" need to know who carries what.
    if (hla_has_typing()) {
      selectInput(
        "hla_scope",
        "Network scope:",
        choices = c(
          "All cells (one graph, allele re-colours it)" = "all",
          "One HLA allele (rebuild on its carriers)" = "allele"
        ),
        selected = hla_param("hla_scope", "all")
      )
    },
    selectInput(
      "hla_color_by",
      "Colour nodes by:",
      choices = color_choices,
      selected = hla_param("hla_color_by", "")
    ),
    # The page's single allele. It drives the carrier colouring AND the allele
    # scope, so it is shown for either. Under "all" scope, changing it only
    # re-colours the cached graph; under "allele" scope it is a build parameter
    # and rebuilds the Hamming distance matrix.
    conditionalPanel(
      condition = paste(
        "input.hla_color_by == 'hla_carrier'",
        "|| input.hla_scope == 'allele'"
      ),
      uiOutput("hla_color_allele_ui")
    ),
    uiOutput("hla_scope_status"),
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
    ## The typing warning above covers the HLA side only. Colouring the network
    ## by carrier status is itself an association display, so a declared
    ## selection caveat has to reach every tab, not just HLA Associations.
    if (!is.null(hla_selection_caveat())) {
      tags$p(
        class = "text-warning",
        style = "font-size: 12px;",
        tags$b(hla_selection_caveat()$headline)
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

## ---- What the current scope actually kept ----------------------------- ##
## A scope silently dropping most of the data is the failure mode here: the user
## sees a smaller network and has no way to tell whether the allele is rare, the
## class filter bit, or the lineage was Unknown. State the counts.
output$hla_scope_status <- renderUI({
  if (!identical(hla_scope_mode(), "allele")) {
    return(NULL)
  }
  full <- hla_segments()
  scoped <- hla_scoped_segments()
  allele <- hla_color_allele()
  if (is.null(full) || is.null(allele)) {
    return(NULL)
  }
  n_full <- nrow(full)
  n_scoped <- if (is.null(scoped)) 0L else nrow(scoped)
  cls <- hla_locus_class(hla_allele_locus(allele))
  has_ctx <- "mhc_context" %in% colnames(full)
  noun <- hla_unit_noun()
  tagList(
    tags$p(
      class = if (n_scoped == 0) "text-danger" else "text-muted",
      style = "font-size: 12px;",
      sprintf(
        "Scope: %s of %s %ss — carriers of %s%s.",
        format(n_scoped, big.mark = ","),
        format(n_full, big.mark = ","),
        noun,
        allele,
        if (has_ctx && cls %in% c("Class I", "Class II")) {
          sprintf(", %s lineage only", cls)
        } else {
          ""
        }
      )
    ),
    # A bulk repertoire has no lineage to match on. Saying so beats letting the
    # user read a carrier-only scope as class-matched.
    if (!has_ctx) {
      tags$p(
        class = "text-warning",
        style = "font-size: 12px;",
        paste(
          "No lineage available, so this scope is carriers only and is NOT",
          "class-matched."
        )
      )
    },
    if (n_scoped == 0) {
      tags$p(
        class = "text-danger",
        style = "font-size: 12px;",
        sprintf(
          "Nothing in scope: no typed carrier of %s has a %s-lineage cell here.",
          allele,
          cls
        )
      )
    },
    # The scope removes the comparison group. That is the whole reason the
    # carrier colouring on the "All cells" scope exists, so say it here rather
    # than let a carrier-only network read as evidence.
    tags$p(
      class = "text-muted",
      style = "font-size: 12px;",
      paste(
        "Every donor in this scope is a carrier, so recurrence across donors",
        "here cannot be told apart from an ordinary public TCR. Use the",
        "\"All cells\" scope with HLA carrier colouring for that contrast."
      )
    )
  )
})
