##----------------------------------------------------------------------------##
## HLA & TCR Motifs — HLA Associations tab
##
## MVP: strictly DESCRIPTIVE donor/allele summaries. No enrichment test, no
## p-value. A donor carrying an allele is a candidate co-occurrence, not a
## confirmed restriction; inferential association needs donor-level statistics
## and a pre-specified plan (design §10), deliberately out of scope here.
##----------------------------------------------------------------------------##

## ---- Per-allele carrier summary over the IR samples ------------------- ##
hla_carrier_summary_tbl <- reactive({
  t <- hla_active_typing()
  if (!hla_has_typing()) {
    return(NULL)
  }
  ir_samples <- names(getImmuneRepertoire())
  hla_allele_carrier_summary(t, samples = ir_samples)
})

output$hla_associations_ui <- renderUI({
  if (!hla_has_typing()) {
    return(tags$p(
      class = "text-muted",
      paste(
        "No HLA typing loaded. Provide donor-level HLA typing in the",
        "Data & QC tab to see carrier summaries for alleles."
      )
    ))
  }
  tagList(
    tags$div(
      class = "alert alert-info",
      style = "font-size: 13px;",
      tags$b("Descriptive overlap only."),
      " Inferential association testing is not enabled in this version. ",
      "Counts are per HLA-typed sample; an allele's carriers are candidate ",
      "co-occurrences, not confirmed TCR restrictions."
    ),
    DT::dataTableOutput("hla_carrier_table")
  )
})

output$hla_carrier_table <- DT::renderDataTable({
  df <- hla_carrier_summary_tbl()
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  # Friendly column names; keep the raw carrier list for provenance.
  show <- data.frame(
    Allele = df$allele,
    Locus = df$locus,
    `MHC class` = df$mhc_class,
    Carriers = df$n_carrier,
    `Non-carriers` = df$n_noncarrier,
    Untyped = df$n_untyped,
    `Carrier samples` = df$carriers,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  DT::datatable(
    show,
    rownames = FALSE,
    options = list(
      pageLength = 15,
      order = list(list(3, "desc")),
      dom = "tip"
    )
  )
})
