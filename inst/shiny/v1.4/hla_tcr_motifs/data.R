##----------------------------------------------------------------------------##
## HLA & TCR Motifs — data layer (reactive composition)
##
## Core algorithms live in the package (R/hla_motif_core.R, R/hla_typing.R);
## this file only wires reactives. Nothing here recomputes a distance matrix on
## a display-only change — the graph reactive is keyed on the build parameters
## and the active dataset, colour/legend changes are handled in the renderer.
##----------------------------------------------------------------------------##

## ---- Optional-dependency gate ----------------------------------------- ##
## visNetwork + stringdist are Imports, so they are present in a normal install.
## The gate stays as a defensive guard for unusual environments.
hla_has_deps <- function() {
  requireNamespace("stringdist", quietly = TRUE) &&
    requireNamespace("igraph", quietly = TRUE) &&
    requireNamespace("visNetwork", quietly = TRUE)
}

## ---- Per-session cache wrapper (module-local, no cross-module coupling) ##
## cache = "session" keeps caches isolated per user; the selected dataset is
## appended to every key at the call site so switching datasets invalidates it.
hla_bindCache <- function(x, ..., cache = "session") {
  if (utils::packageVersion("shiny") >= "1.6.0") {
    shiny::bindCache(x, ..., cache = cache)
  } else {
    x
  }
}

## ---- Metadata-annotated IR data (barcode-joined) ---------------------- ##
## Reuse the same join contract as the IR module: the IR tables carry only
## scRepertoire columns; biological grouping lives in cell metadata, attached
## here by barcode so the page can colour by any metadata column.
hla_ir_annotated <- reactive({
  data <- getImmuneRepertoire()
  if (is.null(data) || !is.list(data) || length(data) == 0) {
    return(NULL)
  }
  md <- tryCatch(getMetaData(), error = function(e) NULL)
  if (is.null(md) || !("cell_barcode" %in% colnames(md))) {
    return(data)
  }
  meta_cols <- setdiff(colnames(md), "cell_barcode")
  lapply(data, function(df) {
    if (is.null(df) || !("barcode" %in% colnames(df))) {
      return(df)
    }
    add <- setdiff(meta_cols, colnames(df))
    if (length(add) == 0) {
      return(df)
    }
    idx <- match(df$barcode, md$cell_barcode)
    for (col in add) {
      df[[col]] <- md[[col]][idx]
    }
    df
  })
})

## ---- TCR chains available (TRA / TRB only for this page) --------------- ##
hla_tcr_chains <- reactive({
  intersect(
    tryCatch(hla_detect_chains(getImmuneRepertoire()), error = function(e) {
      character(0)
    }),
    c("TRA", "TRB")
  )
})

## ---- Active chain (default TRB when present) --------------------------- ##
hla_active_chain <- reactive({
  ch <- input$hla_chain
  chains <- hla_tcr_chains()
  if (!is.null(ch) && nzchar(ch) && ch %in% chains) {
    return(ch)
  }
  if ("TRB" %in% chains) {
    return("TRB")
  }
  if (length(chains) > 0) {
    return(chains[1])
  }
  "TRB"
})

## ---- Read a build/display parameter with a default -------------------- ##
hla_param <- function(id, default = NULL) {
  v <- input[[id]]
  if (is.null(v)) default else v
}

## ---- Metadata columns offered for node colouring ---------------------- ##
## Categorical metadata columns (character/factor, > 1 value) that are not raw
## scRepertoire columns. "sample" and "cell_type" are surfaced first as the
## common colouring choices.
HLA_SCR_COLS <- c(
  "barcode",
  "CTgene",
  "CTnt",
  "CTaa",
  "CTstrict",
  "clonalProportion",
  "clonalFrequency",
  "cloneSize",
  "Frequency",
  "frequency",
  "cloneType"
)
hla_color_meta_cols <- reactive({
  data <- hla_ir_annotated()
  if (is.null(data)) {
    return(character(0))
  }
  common <- Reduce(intersect, lapply(data, colnames))
  merged <- do.call(
    rbind,
    lapply(data, function(df) df[, common, drop = FALSE])
  )
  cand <- setdiff(common, HLA_SCR_COLS)
  keep <- vapply(
    cand,
    function(col) {
      v <- merged[[col]]
      (is.character(v) || is.factor(v)) &&
        length(unique(v[!is.na(v) & nzchar(as.character(v))])) > 1
    },
    logical(1)
  )
  cols <- cand[keep]
  ordered <- intersect(c("sample", "cell_type"), cols)
  c(ordered, setdiff(cols, ordered))
})

## Colouring by a column with more distinct values than this is unreadable: the
## legend is suppressed and every point gets a near-arbitrary hue, so the control
## would promise a grouping it cannot show. Such columns are not offered.
HLA_MAX_COLOR_LEVELS <- 24L

## ---- Colour columns that can actually be read -------------------------- ##
## hla_color_meta_cols() keeps any categorical column with > 1 level, but a
## column with a level per sample (e.g. `sample` / `donor_id` in a 100-donor
## cohort) yields ~100 hues and a suppressed legend: the control would offer a
## grouping the plot cannot convey. Cap the cardinality for the colour picker
## only; such columns remain available as node tooltips.
hla_usable_color_cols <- reactive({
  cols <- hla_color_meta_cols()
  if (length(cols) == 0) {
    return(character(0))
  }
  data <- hla_ir_annotated()
  if (is.null(data)) {
    return(cols)
  }
  n_levels <- vapply(
    cols,
    function(col) {
      v <- unlist(lapply(data, function(df) {
        if (col %in% colnames(df)) as.character(df[[col]]) else character(0)
      }))
      length(unique(v[!is.na(v) & nzchar(v)]))
    },
    integer(1)
  )
  cols[n_levels <= HLA_MAX_COLOR_LEVELS]
})

## ---- Does the source key its receptors on V gene + CDR3? --------------- ##
## Node identity defaults to the CDR3 alone, which is right when the source
## reports a full rearrangement. Some sources (bulk V-family + CDR3, e.g. the
## Emerson/pubtcrs cohort) define a receptor as the PAIR: merging on CDR3 alone
## would fuse receptors the source counts as distinct and double-count a donor
## across them. The .crb declares this in `technical_info$receptor_key`;
## "v_gene+cdr3" makes split-by-V the default. The user can still override.
hla_source_keys_on_v <- reactive({
  ti <- tryCatch(data_set()$technical_info, error = function(e) NULL)
  is.list(ti) && identical(ti$receptor_key, "v_gene+cdr3")
})

hla_by_v_default <- reactive({
  isTRUE(hla_source_keys_on_v())
})

## ---- Default minimum motif size --------------------------------------- ##
## A fixed default of 2 keeps every 2-node component, which on a real repertoire
## means thousands of nodes in hundreds of tiny motifs: physics is disabled, the
## layout collapses to a ring and the first thing the user sees is a hairball.
## Scale the default to the data instead, so the first view is a readable set of
## the larger motifs; the slider still exposes the full range down to 2.
hla_default_min_nodes <- reactive({
  seg <- hla_segments()
  if (is.null(seg) || nrow(seg) == 0) {
    return(2L)
  }
  n_cdr3 <- length(unique(seg$cdr3))
  if (n_cdr3 > 2000) {
    6L
  } else if (n_cdr3 > 500) {
    4L
  } else {
    2L
  }
})

## ---- HLA alleles offered for carrier colouring ------------------------ ##
## Labelled with the carrier / non-carrier split and ordered by how much
## contrast they can show. An allele carried by everyone (or by nobody) in the
## cohort colours the whole network one shade, so those sort last.
hla_allele_choices <- reactive({
  if (!hla_has_typing()) {
    return(character(0))
  }
  typing <- hla_active_typing()
  samples <- names(getImmuneRepertoire())
  summ <- hla_allele_carrier_summary(typing, samples = samples)
  if (is.null(summ) || nrow(summ) == 0) {
    return(character(0))
  }
  # Offer ONLY the loci this version can interpret (HLA_MVP_LOCI: A/B/C/DRB1).
  # DQ and DP are alpha/beta heterodimers: a lone DQB1 or DPB1 allele is not an
  # independently interpretable unit without pairing/phasing, so presenting one
  # in an allele picker would invite exactly the over-reading the page exists to
  # avoid. Other loci stay stored and visible in Data & QC, just not offered
  # here as an analysis axis.
  summ <- summ[summ$locus %in% HLA_MVP_LOCI, , drop = FALSE]
  if (nrow(summ) == 0) {
    return(character(0))
  }
  # Informativeness = the size of the smaller of the two groups: that is the
  # most donors a carrier/non-carrier contrast could ever rest on.
  contrast <- pmin(summ$n_carrier, summ$n_noncarrier)
  ord <- order(-contrast, -summ$n_carrier, summ$allele)
  summ <- summ[ord, , drop = FALSE]
  stats::setNames(
    summ$allele,
    sprintf(
      "%s - %d carrier / %d non-carrier",
      summ$allele,
      summ$n_carrier,
      summ$n_noncarrier
    )
  )
})

## ---- Allele currently colouring the network --------------------------- ##
## Falls back to the most informative allele so the first carrier render is
## meaningful before the picker has reported a value.
## ONE allele for the whole page. The network's colour and the Associations
## tables must answer the same question: two independent pickers let the user
## colour by one allele while reading another's numbers, and nothing on screen
## would reveal the mismatch. Either control writes this input.
hla_color_allele <- reactive({
  choices <- hla_allele_choices()
  if (length(choices) == 0) {
    return(NULL)
  }
  a <- input$hla_color_allele
  if (!is.null(a) && nzchar(a) && a %in% choices) {
    return(a)
  }
  unname(choices[1])
})

## Keep the Associations picker and the network picker pointing at one allele.
observeEvent(input$hla_association_allele, {
  a <- input$hla_association_allele
  if (!is.null(a) && nzchar(a) && !identical(a, input$hla_color_allele)) {
    updateSelectInput(session, "hla_color_allele", selected = a)
  }
})
observeEvent(input$hla_color_allele, {
  a <- input$hla_color_allele
  if (!is.null(a) && nzchar(a) && !identical(a, input$hla_association_allele)) {
    updateSelectInput(session, "hla_association_allele", selected = a)
  }
})

## ---- What one row of the data actually is ----------------------------- ##
## A .crb row is a cell for single-cell data, but the bulk cohort demo maps a
## (donor, clonotype) pair onto a row. Detect it from the data rather than
## trusting a label: with no genes measured there was no transcriptome, so the
## rows cannot be cells. Used to name node size honestly in the tooltip.
hla_unit_noun <- reactive({
  n_genes <- tryCatch(nrow(data_set()$expression), error = function(e) NULL)
  if (!is.null(n_genes) && n_genes == 0) "analysis unit" else "cell"
})

## ---- Cell-type column used for lineage-derived MHC context ------------- ##
## Prefer a finer lineage column (cell_type_fine) when present, since a coarse
## "T cells" label cannot separate CD4/CD8 and collapses to Unknown context.
hla_celltype_col <- reactive({
  cols <- hla_color_meta_cols()
  if ("cell_type_fine" %in% cols) {
    "cell_type_fine"
  } else if ("cell_type" %in% cols) {
    "cell_type"
  } else {
    NA_character_
  }
})

## ---- Parsed segments for the active chain (+ per-cell MHC context) ----- ##
hla_segments <- reactive({
  data <- hla_ir_annotated()
  chain <- hla_active_chain()
  if (is.null(data)) {
    return(NULL)
  }
  seg <- hla_parse_ir_segments(data, chain)
  if (is.null(seg) || nrow(seg) == 0) {
    return(seg)
  }
  ct_col <- hla_celltype_col()
  if (!is.na(ct_col) && ct_col %in% colnames(seg)) {
    seg$mhc_context <- hla_lineage_context(seg[[ct_col]])
  }
  seg
})

## ---- Metadata columns to carry onto nodes (for tooltip / colouring) ---- ##
hla_node_meta_cols <- reactive({
  cols <- hla_color_meta_cols()
  # Always carry sample + cell_type when present (used by evidence join / MHC
  # context), plus whatever the user colours by.
  base <- intersect(c("sample", "cell_type"), cols)
  cb <- hla_param("hla_color_by", "")
  unique(c(base, if (nzchar(cb) && cb %in% cols) cb else character(0)))
})

## ---- The motif graph (heavy; keyed on build parameters) --------------- ##
## Only build parameters (chain, min_nodes, split-by-V, show-isolated) and the
## dataset re-trigger this; colour is applied downstream in the renderer.
hla_motif_graph <- reactive({
  if (!hla_has_deps()) {
    return(NULL)
  }
  seg <- hla_segments()
  if (is.null(seg) || nrow(seg) == 0) {
    return(NULL)
  }
  ctx_col <- if ("mhc_context" %in% colnames(seg)) "mhc_context" else NULL
  hla_build_motif_graph(
    seg,
    by_v = isTRUE(hla_param("hla_by_v", hla_by_v_default())),
    min_nodes = as.integer(hla_param("hla_min_nodes", hla_default_min_nodes())),
    show_isolated = isTRUE(hla_param("hla_show_isolated", FALSE)),
    meta_cols = hla_node_meta_cols(),
    context_col = ctx_col
  )
}) %>%
  hla_bindCache(
    hla_active_chain(),
    hla_param("hla_by_v", hla_by_v_default()),
    hla_param("hla_min_nodes", hla_default_min_nodes()),
    hla_param("hla_show_isolated", FALSE),
    paste(hla_node_meta_cols(), collapse = ","),
    available_crb_files$selected
  )

## ---- Selection provenance of the receptor set -------------------------- ##
## A data set may have been assembled by SELECTING receptors on the very HLA
## association the page then displays (a positive control). The carrier/
## non-carrier contrast is then true but circular: it was put there by the
## selection, and re-computing overlap on it is not independent evidence.
##
## This cannot be inferred from the data, so the .crb must declare it in
## `technical_info$tcr_selection`:
##   "association-conditioned" -> receptors were chosen using an HLA association
##   "unselected"              -> receptors were not chosen using HLA
## `technical_info$tcr_selection_detail` carries the human-readable specifics.
## Anything else (or absent) is treated as unknown and stays silent, so this
## never invents a caveat for a data set that did not declare one.
hla_selection_caveat <- reactive({
  ti <- tryCatch(data_set()$technical_info, error = function(e) NULL)
  if (!is.list(ti) || !identical(ti$tcr_selection, "association-conditioned")) {
    return(NULL)
  }
  ti$tcr_selection_detail %||%
    paste(
      "This data set's receptors were selected using a published HLA",
      "association, so a carrier/non-carrier difference here is expected by",
      "construction and is not independent evidence."
    )
})

## ---- Stored HLA typing (canonical long table) ------------------------- ##
hla_stored_typing <- reactive({
  getHLATyping()
})

## ---- Session HLA override (from Data & QC upload) --------------------- ##
## Session-only; never written back to the .crb. NULL until the user uploads
## and activates a session source.
hla_session_typing <- reactiveVal(NULL)

## Drop the session override the moment the data set changes. HLA is matched to
## samples by exact name, so an override uploaded for one data set could
## silently re-attach to same-named samples in the next one and present another
## cohort's genotypes as this one's. Uploading again after switching is a small
## cost; showing the wrong donor's HLA is not recoverable by the reader.
observeEvent(available_crb_files$selected, ignoreInit = TRUE, {
  if (!is.null(hla_session_typing())) {
    hla_session_typing(NULL)
    showNotification(
      "Data set changed - the uploaded HLA typing was cleared.",
      type = "warning"
    )
  }
})

## ---- Active typing (session override wins over stored) ---------------- ##
hla_active_typing <- reactive({
  sess <- hla_session_typing()
  if (!is.null(sess) && is.data.frame(sess) && nrow(sess) > 0) {
    return(sess)
  }
  hla_stored_typing()
})

## ---- Does the active typing cover anything? --------------------------- ##
hla_has_typing <- reactive({
  t <- hla_active_typing()
  is.data.frame(t) && nrow(t) > 0
})
