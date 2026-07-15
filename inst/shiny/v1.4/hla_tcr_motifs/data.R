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
    by_v = isTRUE(hla_param("hla_by_v", FALSE)),
    min_nodes = as.integer(hla_param("hla_min_nodes", 2L)),
    show_isolated = isTRUE(hla_param("hla_show_isolated", FALSE)),
    meta_cols = hla_node_meta_cols(),
    context_col = ctx_col
  )
}) %>%
  hla_bindCache(
    hla_active_chain(),
    hla_param("hla_by_v", FALSE),
    hla_param("hla_min_nodes", 2L),
    hla_param("hla_show_isolated", FALSE),
    paste(hla_node_meta_cols(), collapse = ","),
    available_crb_files$selected
  )

## ---- Stored HLA typing (canonical long table) ------------------------- ##
hla_stored_typing <- reactive({
  getHLATyping()
})

## ---- Session HLA override (from Data & QC upload) --------------------- ##
## Session-only; never written back to the .crb. NULL until the user uploads
## and activates a session source.
hla_session_typing <- reactiveVal(NULL)

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
