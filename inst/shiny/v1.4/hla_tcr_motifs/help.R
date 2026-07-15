##----------------------------------------------------------------------------##
## HLA & TCR Motifs — help modals + placeholder tab bodies
##
## The Data & QC and HLA Associations tab bodies are defined in data_qc.R and
## associations.R (later phases). This file holds the info-button modals.
##----------------------------------------------------------------------------##

observeEvent(input$hla_parameters_info, {
  showModal(modalDialog(
    title = "Parameters",
    easyClose = TRUE,
    size = "l",
    tagList(
      tags$p(
        tags$b("Chain"),
        " — which TCR chain's CDR3 to cluster (TRB by default)."
      ),
      tags$p(
        tags$b("Colour nodes by"),
        " — motif cluster (default) or a metadata column."
      ),
      tags$p(
        tags$b("Minimum motif size"),
        " — keep connected components with at least this many CDR3 nodes."
      ),
      tags$p(
        tags$b("Split motifs by V gene"),
        " — cluster within each V gene, so identical CDR3s on different V genes are separate."
      ),
      tags$p(
        tags$b("Show unconnected CDR3s"),
        " — also draw CDR3s that have no Hamming-1 neighbour."
      ),
      tags$p(
        "Edges always use Hamming distance 1: two equal-length CDR3s that differ at exactly one position are joined."
      )
    )
  ))
})

observeEvent(input$hla_status_info, {
  showModal(modalDialog(
    title = "Evidence status",
    easyClose = TRUE,
    size = "l",
    tagList(
      tags$p("This page separates what is observed from what is inferred:"),
      tags$ul(
        tags$li(
          tags$b("Observed"),
          " — a sample's HLA genotype, a cell's CD4/CD8 annotation, a CDR3's sequence, and which samples carry a CDR3."
        ),
        tags$li(
          tags$b("Lineage-derived MHC context"),
          " — CD8 to Class I, CD4/Treg to Class II. This is context, not restriction."
        ),
        tags$li(
          tags$b("Association"),
          " — a motif enriched among carriers of an allele across donors. Descriptive only in this version."
        ),
        tags$li(
          tags$b("Validated restriction"),
          " — only from external pMHC / functional evidence. Not produced here."
        )
      ),
      tags$p(
        tags$b(
          "A donor carrying an HLA allele does not mean every one of that donor's TCRs is restricted by it."
        ),
        " Alleles shown for a motif are candidate co-occurrences that generate hypotheses; confirming restriction needs population statistics and experimental validation."
      )
    )
  ))
})
