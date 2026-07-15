##----------------------------------------------------------------------------##
## HLA & TCR Motifs — HLA Associations tab (Phase F)
##
## Placeholder body; filled in Phase F (descriptive donor/allele summaries,
## carrier overlap, donor x allele matrix, unique-clonotype/cell fractions —
## no inferential statistics).
##----------------------------------------------------------------------------##

output$hla_associations_ui <- renderUI({
  if (!hla_has_typing()) {
    return(tags$p(
      class = "text-muted",
      paste(
        "No HLA typing loaded. Provide donor-level HLA typing in the",
        "Data & QC tab to see carrier summaries for motifs."
      )
    ))
  }
  tags$p(
    class = "text-muted",
    "Descriptive HLA carrier summaries will appear here."
  )
})
