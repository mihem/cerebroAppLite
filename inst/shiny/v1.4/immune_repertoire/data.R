## ---- Reactive: raw repertoire data (as stored in crb) ------------------ ##
ir_data_raw <- reactive({
  req(!is.null(data_set()))
  data <- getImmuneRepertoire()
  if (is.null(data) || !is.list(data) || length(data) == 0) {
    return(NULL)
  }
  data
})

## ---- Standard scRepertoire columns (not usable as grouping) ----------- ##
ir_scr_cols <- c(
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

## ---- Join cell metadata onto every IR row by barcode ------------------ ##
## The IR data.frames carry only scRepertoire columns (barcode, CT*). Any
## biological grouping (sample, condition, treatment, cell type, ...) lives in
## the data set's cell metadata. We attach it here by `cell_barcode` so the
## module can group/split by ANY metadata column, not just whatever columns a
## data producer happened to embed in the IR table.
ir_data_annotated <- reactive({
  data <- ir_data_raw()
  if (is.null(data)) {
    return(NULL)
  }
  md <- tryCatch(getMetaData(), error = function(e) NULL)
  if (is.null(md) || !("cell_barcode" %in% colnames(md))) {
    return(data) # nothing to join; fall back to raw IR data
  }
  # metadata columns that don't already exist in the IR tables
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
    n_miss <- sum(is.na(idx))
    if (n_miss > 0) {
      warning(sprintf(
        paste0(
          "[IR] %d / %d clonotype barcodes not found in cell metadata; ",
          "grouping/splitting by metadata columns may be incomplete. ",
          "Check that IR barcodes match the cell barcodes (e.g. the '-1' suffix)."
        ),
        n_miss,
        length(idx)
      ))
    }
    for (col in add) {
      df[[col]] <- md[[col]][idx]
    }
    df
  })
})

## ---- Reactive: repertoire data --------------------------------------- ##
## Returns the metadata-annotated repertoire list as loaded. Grouping is not
## done here: scRepertoire's own group.by rbinds the list and re-splits on the
## chosen column (.groupList), so an in-app re-split would only duplicate — with
## a narrower, sample-only column set — what group.by already does. Comparison
## units are therefore expressed solely through ir_groupBy / group.by.
ir_data <- reactive({
  ir_data_annotated()
})

## ---- Helper: read a dynamic function-specific parameter --------------- ##
## The function-specific controls (IR_PARAM_SPEC) are rendered into a dynamic
## panel, so an input may be absent on tabs where the parameter doesn't apply.
## Returns `default` when the input is missing/empty.
ir_param <- function(id, default = NULL) {
  v <- input[[id]]
  if (is.null(v)) default else v
}

## ---- Resolve the generic "Order groups" (order.by) value -------------- ##
## Maps the ir_p_order_by control to scRepertoire's order.by argument: the
## empty default becomes NULL (scRepertoire's own ordering), otherwise the
## chosen value (e.g. "alphanumeric") is passed through.
ir_order_by <- function() {
  v <- input[["ir_p_order_by"]]
  if (is.null(v) || !nzchar(v)) NULL else v
}

## ---- Parse the Homeostasis clone-size thresholds ---------------------- ##
## clonalHomeostasis' cloneSize is a *named* numeric vector of upper bounds
## (Rare < Small < ... < Hyperexpanded). The UI takes them as a comma-separated
## list of 5 increasing numbers; this builds the named vector. Returns NULL on
## anything malformed so scRepertoire falls back to its own default.
IR_CLONE_SIZE_NAMES <- c(
  "Rare",
  "Small",
  "Medium",
  "Large",
  "Hyperexpanded"
)
IR_CLONE_SIZE_DEFAULT <- setNames(
  c(1e-04, 0.001, 0.01, 0.1, 1),
  IR_CLONE_SIZE_NAMES
)
ir_clone_size <- function() {
  v <- input[["ir_p_clone_size"]]
  if (is.null(v) || !nzchar(v)) {
    return(IR_CLONE_SIZE_DEFAULT)
  }
  nums <- suppressWarnings(as.numeric(trimws(strsplit(v, ",")[[1]])))
  if (
    length(nums) != length(IR_CLONE_SIZE_NAMES) ||
      any(is.na(nums)) ||
      is.unsorted(nums, strictly = TRUE)
  ) {
    return(IR_CLONE_SIZE_DEFAULT)
  }
  setNames(nums, IR_CLONE_SIZE_NAMES)
}

## ---- Comparable groups for Scatter / Compare ------------------------- ##
## clonalScatter (x.axis/y.axis) and clonalCompare (samples) operate on the
## *names of the groups that group.by produces*. With group.by = None the
## groups are the list elements (samples); with group.by = <column> they are
## that column's levels. This reactive returns those group names so the Scatter
## X/Y and Compare selectors stay in sync with the active grouping.
ir_compare_groups <- reactive({
  data <- ir_data()
  if (is.null(data)) {
    return(character(0))
  }
  gb <- input$ir_groupBy
  if (is.null(gb) || !nzchar(gb)) {
    return(names(data))
  }
  vals <- unique(unlist(lapply(data, function(df) {
    if (gb %in% colnames(df)) as.character(df[[gb]]) else character(0)
  })))
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0) names(data) else sort(vals)
})

## ---- Candidate columns for the Sharing "unit" selector ---------------- ##
## The Sharing tab needs a "smallest sharing unit" (default: sample). Offer any
## metadata column that is categorical (character/factor with > 1 distinct
## non-empty value) and is not a raw scRepertoire column (ir_scr_cols). `sample`
## is placed first so it becomes the default selection.
ir_sharing_unit_choices <- reactive({
  data <- ir_data()
  if (is.null(data)) {
    return(character(0))
  }
  common <- Reduce(intersect, lapply(data, colnames))
  merged <- do.call(
    rbind,
    lapply(data, function(df) {
      df[, common, drop = FALSE]
    })
  )
  cand <- setdiff(common, ir_scr_cols)
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
  if ("sample" %in% cols) c("sample", setdiff(cols, "sample")) else cols
})

## ---- Node-colour choices for the Motif Network tab --------------------- ##
## "By motif cluster" (value "") plus categorical metadata columns. Scanning
## every column surfaces technical/redundant ones (orig.ident, RNA_snn_res.*)
## that the rest of Cerebro hides, so the candidates are restricted to the
## registered grouping variables (getGroups(), the same whitelist the Groups
## tab uses), intersected with the columns actually present on the repertoire
## data. `sample` is always kept — it is the primary repertoire unit and shown
## on the Groups tab too. Falls back to the full scan when no grouping variables
## are registered, so the control never collapses to just "By motif cluster".
ir_motif_color_choices <- reactive({
  cols <- ir_sharing_unit_choices()
  groups <- tryCatch(getGroups(), error = function(e) NULL)
  if (length(groups) > 0) {
    allowed <- union("sample", groups)
    cols <- cols[cols %in% allowed]
  }
  c("By motif cluster" = "", cols)
})

## ---- Reactive: parameters --------------------------------------------- ##
ir_params <- reactive({
  gb <- input$ir_groupBy
  if (is.null(gb) || gb == "") {
    gb <- NULL
  }
  list(
    cloneCall = input$ir_cloneCall,
    chain = input$ir_chain,
    groupBy = gb
  )
})

## ---- Reactive: number of groups for faceted plots --------------------- ##
n_groups <- reactive({
  gb <- ir_params()$groupBy
  if (is.null(gb)) {
    return(1L)
  }
  data <- ir_data()
  if (is.null(data)) {
    return(1L)
  }
  lvls <- unique(unlist(lapply(data, function(df) {
    if (gb %in% names(df)) unique(as.character(df[[gb]])) else character(0)
  })))
  max(1L, length(lvls))
})

## ---- Dynamic gene parameter for vizGenes/percentGeneUsage ------------- ##
default_gene_family <- reactive({
  chains <- detect_chains(ir_data())
  tcr_chains <- intersect(chains, c("TRA", "TRB", "TRG", "TRD"))
  bcr_chains <- intersect(chains, c("IGH", "IGK", "IGL"))
  if (length(tcr_chains) > 0 && "TRB" %in% tcr_chains) {
    return("TRBV")
  }
  if (length(tcr_chains) > 0) {
    return(paste0(tcr_chains[1], "V"))
  }
  if (length(bcr_chains) > 0 && "IGH" %in% bcr_chains) {
    return("IGHV")
  }
  if (length(bcr_chains) > 0) {
    return(paste0(bcr_chains[1], "V"))
  }
  "TRBV"
})

## ---- Resolve chain: for functions that don't accept "both" ------------ ##
specific_chain <- reactive({
  ch <- input$ir_chain
  if (is.null(ch) || ch == "both") {
    chains <- detect_chains(ir_data())
    if ("TRB" %in% chains) {
      return("TRB")
    }
    if (length(chains) > 0) {
      return(chains[1])
    }
    return("TRB")
  }
  ch
})

## ---- Count unique genes for dynamic plot height ----------------------- ##
n_genes <- reactive({
  data <- ir_data()
  if (is.null(data)) {
    return(0L)
  }
  gene_family <- default_gene_family()
  # Gather all gene values across samples
  all_genes <- unique(unlist(lapply(data, function(df) {
    # CTgene has format like "TRBV1.TRBJ2" — extract the gene family portion
    ct <- as.character(df$CTgene)
    ct <- ct[!is.na(ct)]
    # Split by "." and keep segments matching the gene family prefix
    segments <- unlist(strsplit(ct, "[._]"))
    segments[grepl(paste0("^", gene_family), segments, ignore.case = TRUE)]
  })))
  length(all_genes)
})

ir_plot_height <- function(facet_mode = c("none", "grid", "wrap")) {
  facet_mode <- match.arg(facet_mode)
  n <- n_genes()
  ng <- n_groups()
  base_h <- max(450, min(n * 25, 2500))
  if (ng <= 1 || facet_mode == "none") {
    return(base_h)
  }
  if (facet_mode == "grid") {
    # facet_grid(Group ~ .): each group stacked vertically
    return(base_h * ng)
  }
  # facet_wrap: ggplot default ncol = ceiling(sqrt(n))
  ncol <- ceiling(sqrt(ng))
  nrow <- ceiling(ng / ncol)
  base_h * nrow
}

##----------------------------------------------------------------------------##
## Clonal UMAP data layer
##----------------------------------------------------------------------------##

## ---- Chains that define each receptor class --------------------------- ##
IR_TCR_CHAINS <- c("TRA", "TRB", "TRG", "TRD")
IR_BCR_CHAINS <- c("IGH", "IGK", "IGL")

## ---- Which receptor classes are present in the data ------------------- ##
## Returns a named vector ("TCR" / "BCR") of the receptor types actually
## detected, so the Clonal UMAP selector only offers what exists. The names
## are the labels shown to the user; values feed ir_umap_chains().
ir_receptor_types <- reactive({
  chains <- tryCatch(detect_chains(ir_data()), error = function(e) character(0))
  types <- character(0)
  if (length(intersect(chains, IR_TCR_CHAINS)) > 0) {
    types <- c(types, "TCR" = "TCR")
  }
  if (length(intersect(chains, IR_BCR_CHAINS)) > 0) {
    types <- c(types, "BCR" = "BCR")
  }
  types
})

## ---- Chains belonging to the selected receptor type ------------------- ##
ir_umap_chains <- function(receptor) {
  if (identical(receptor, "BCR")) IR_BCR_CHAINS else IR_TCR_CHAINS
}

## ---- Clone-size bin breaks / labels (scRepertoire cloneSize defaults) -- ##
## A clone's size = number of cells carrying that clonotype (within the
## selected receptor). Cells are binned into the standard expansion levels.
IR_CLONE_BINS <- c(0, 1, 5, 20, 100, Inf)
IR_CLONE_LABELS <- c(
  "Single (0 < X <= 1)",
  "Small (1 < X <= 5)",
  "Medium (5 < X <= 20)",
  "Large (20 < X <= 100)",
  "Hyperexpanded (100 < X)"
)

## ---- Which CT* column a cloneCall maps to ----------------------------- ##
ir_clonecall_col <- function(cloneCall) {
  switch(
    cloneCall %||% "gene",
    "gene" = "CTgene",
    "nt" = "CTnt",
    "aa" = "CTaa",
    "strict" = "CTstrict",
    "CTgene"
  )
}

## ---- Clonal UMAP data: coords + per-cell expansion level --------------- ##
## Joins the chosen projection's UMAP coordinates (barcode-indexed) with each
## cell's clone-expansion level, restricted to the selected receptor (TCR/BCR).
## Returns a data.frame (x, y, expansion, barcode) or NULL when it cannot be
## built (no projection, no data for the receptor, no overlapping barcodes).
##
##   projection : a name from availableProjections()
##   receptor   : "TCR" | "BCR"
##   cloneCall  : "gene" | "nt" | "aa" | "strict" (clone identity column)
##   show_all   : when TRUE, also include every other cell in the projection
##                with expansion = NA (drawn as a grey background by the
##                renderer), so the receptor cells are shown in context.
##   cells      : optional character vector of barcodes to restrict to (e.g.
##                from the Group filters); NULL = all cells in the projection.
ir_clonal_umap_data <- function(
  projection,
  receptor,
  cloneCall = "gene",
  show_all = TRUE,
  cells = NULL
) {
  if (is.null(projection) || !nzchar(projection)) {
    return(NULL)
  }
  if (
    !(projection %in%
      tryCatch(availableProjections(), error = function(e) character(0)))
  ) {
    return(NULL)
  }
  coords <- tryCatch(getProjection(projection), error = function(e) NULL)
  if (is.null(coords) || nrow(coords) == 0) {
    return(NULL)
  }
  # Restrict to the requested cells (group filters) up front, so both the
  # coloured receptor cells and the grey background respect the filter.
  if (!is.null(cells)) {
    coords <- coords[rownames(coords) %in% cells, , drop = FALSE]
    if (nrow(coords) == 0) {
      return(NULL)
    }
  }

  data <- ir_data_annotated()
  if (is.null(data)) {
    return(NULL)
  }
  clone_col <- ir_clonecall_col(cloneCall)
  keep_chains <- ir_umap_chains(receptor)

  # Flatten the per-sample IR list into one barcode -> clonotype table,
  # restricted to rows whose CTstrict/CTgene references one of the receptor's
  # chains. Each row is one cell (scRepertoire keeps one row per barcode).
  rows <- lapply(data, function(df) {
    if (is.null(df) || !all(c("barcode", clone_col) %in% colnames(df))) {
      return(NULL)
    }
    chain_ref <- if ("CTstrict" %in% colnames(df)) {
      as.character(df$CTstrict)
    } else {
      as.character(df[[clone_col]])
    }
    in_receptor <- vapply(
      chain_ref,
      function(s) {
        any(vapply(
          keep_chains,
          function(ch) grepl(ch, s, fixed = TRUE),
          logical(1)
        ))
      },
      logical(1)
    )
    df <- df[in_receptor, , drop = FALSE]
    if (nrow(df) == 0) {
      return(NULL)
    }
    data.frame(
      barcode = as.character(df$barcode),
      clone = as.character(df[[clone_col]]),
      stringsAsFactors = FALSE
    )
  })
  rows <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  has_receptor <- !is.null(rows) && nrow(rows) > 0
  if (has_receptor) {
    # Clone size = number of cells sharing the clonotype; bin into expansion levels.
    rows <- rows[!is.na(rows$clone) & nzchar(rows$clone), , drop = FALSE]
  }
  if (!has_receptor || nrow(rows) == 0) {
    # No receptor cells. With show_all we can still draw the grey background;
    # otherwise there is nothing to plot.
    if (!isTRUE(show_all)) {
      return(NULL)
    }
    rows <- data.frame(
      barcode = character(0),
      clone = character(0),
      stringsAsFactors = FALSE
    )
    has_receptor <- FALSE
  } else {
    sizes <- table(rows$clone)
    rows$size <- as.integer(sizes[rows$clone])
    rows$expansion <- cut(
      rows$size,
      breaks = IR_CLONE_BINS,
      labels = IR_CLONE_LABELS,
      right = TRUE,
      include.lowest = TRUE
    )
  }

  coord_bc <- rownames(coords)

  # Coloured layer: receptor cells with an expansion level, joined to coords.
  if (has_receptor) {
    idx <- match(rows$barcode, coord_bc)
    ok <- !is.na(idx)
    rows <- rows[ok, , drop = FALSE]
    idx <- idx[ok]
  } else {
    idx <- integer(0)
  }
  if (length(idx) == 0 && !isTRUE(show_all)) {
    return(NULL)
  }
  coloured <- if (length(idx) > 0) {
    xy <- coords[idx, 1:2, drop = FALSE]
    data.frame(
      x = as.numeric(xy[[1]]),
      y = as.numeric(xy[[2]]),
      expansion = factor(rows$expansion, levels = IR_CLONE_LABELS),
      barcode = rows$barcode,
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }

  # Background layer: every other cell in the projection, expansion = NA, so the
  # renderer can draw them in grey. Only when show_all is requested.
  background <- NULL
  if (isTRUE(show_all)) {
    bg_mask <- !(coord_bc %in%
      (if (length(idx) > 0) rows$barcode else character(0)))
    if (any(bg_mask)) {
      xy_bg <- coords[bg_mask, 1:2, drop = FALSE]
      background <- data.frame(
        x = as.numeric(xy_bg[[1]]),
        y = as.numeric(xy_bg[[2]]),
        expansion = factor(NA, levels = IR_CLONE_LABELS),
        barcode = coord_bc[bg_mask],
        stringsAsFactors = FALSE
      )
    }
  }

  out <- rbind(background, coloured)
  if (is.null(out) || nrow(out) == 0) {
    return(NULL)
  }
  out
}

##----------------------------------------------------------------------------##
## Clone-segment parsing (shared by the Definition and Sharing tabs)
##----------------------------------------------------------------------------##

## ---- Parse V / J / CDR3 for one chain out of the CT* columns ----------- ##
## scRepertoire packs all chains of a cell into single strings:
##   CTgene : "<chainA gene segs>_<chainB gene segs>"  (chains joined by "_")
##            each chain's segs are V.D.J.C joined by "."  (empty D -> "..")
##            a chain's two alleles are joined by ";"      (take the first)
##   CTaa   : "<chainA CDR3>_<chainB CDR3>"              (chains joined by "_")
## "NA" marks a missing chain. This returns one row per cell that HAS the
## requested chain, with parsed v_gene / j_gene / cdr3 and a combined
## clone_vjc = "v;j;cdr3" id, plus every metadata column already joined onto
## the IR data (so callers can group/split by any of them).
##
##   data  : the metadata-annotated IR list (ir_data_annotated())
##   chain : chain prefix, e.g. "TRB" / "TRA" / "IGH"
ir_parse_segments <- function(data, chain) {
  if (is.null(data) || length(data) == 0 || is.null(chain) || !nzchar(chain)) {
    return(NULL)
  }
  # For each cell's CT* string (chains joined by "_"), find the positional index
  # (1-based) of the chain matching `chain`, then return that slot's value from
  # both CTgene and CTaa in parallel so gene and CDR3 stay aligned.
  # Returns NA when the chain is absent or its slot is "NA".
  chain_slot_index <- function(ct_gene_vec) {
    ct_gene_vec <- as.character(ct_gene_vec)
    vapply(
      strsplit(ct_gene_vec, "_", fixed = TRUE),
      function(parts) {
        # Take first allele of each slot to test chain membership.
        first <- sub(";.*$", "", parts)
        idx <- which(grepl(chain, first, fixed = TRUE) & first != "NA")
        if (length(idx) == 0) NA_integer_ else idx[1]
      },
      integer(1)
    )
  }
  # Given a CT* vector and a per-row slot index, pick that slot's value.
  pick_slot <- function(ct_vec, slot_idx) {
    ct_vec <- as.character(ct_vec)
    vapply(
      seq_along(ct_vec),
      function(i) {
        if (is.na(slot_idx[i])) {
          return(NA_character_)
        }
        parts <- strsplit(ct_vec[i], "_", fixed = TRUE)[[1]]
        if (slot_idx[i] > length(parts)) {
          return(NA_character_)
        }
        val <- parts[slot_idx[i]]
        if (is.na(val) || val == "NA" || !nzchar(val)) NA_character_ else val
      },
      character(1)
    )
  }
  # Take the first allele (before ";") of a chain segment.
  first_allele <- function(x) {
    ifelse(is.na(x), NA_character_, sub(";.*$", "", x))
  }

  rows <- lapply(data, function(df) {
    if (is.null(df) || !all(c("barcode", "CTgene", "CTaa") %in% colnames(df))) {
      return(NULL)
    }
    slot_idx <- chain_slot_index(df$CTgene)
    gene_seg <- first_allele(pick_slot(df$CTgene, slot_idx))
    cdr3 <- first_allele(pick_slot(df$CTaa, slot_idx))
    # From "TRBV6-2..TRBJ2-6.TRBC2" pull the V and J tokens (segs split on ".").
    # NA gene_seg -> strsplit yields NA -> no token matches -> NA gene, dropped.
    pull_token <- function(prefix) {
      vapply(
        strsplit(gene_seg, ".", fixed = TRUE),
        function(toks) {
          hit <- toks[grepl(paste0("^", chain, prefix), toks)]
          if (length(hit) == 0) NA_character_ else hit[1]
        },
        character(1)
      )
    }
    v_gene <- pull_token("V")
    j_gene <- pull_token("J")
    keep <- !is.na(v_gene) & !is.na(j_gene) & !is.na(cdr3) & nzchar(cdr3)
    if (!any(keep)) {
      return(NULL)
    }
    out <- df[keep, , drop = FALSE]
    out$v_gene <- v_gene[keep]
    out$j_gene <- j_gene[keep]
    out$cdr3 <- cdr3[keep]
    out$clone_vjc <- paste(out$v_gene, out$j_gene, out$cdr3, sep = ";")
    out
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(NULL)
  }
  # Align columns before rbind. Use the UNION of all sample columns and NA-fill
  # any a given sample lacks, so per-cohort metadata columns are never silently
  # dropped (intersect would lose them). Column order follows the first sample,
  # with any extra columns from later samples appended.
  all_cols <- unique(unlist(lapply(rows, colnames)))
  rows <- lapply(rows, function(df) {
    miss <- setdiff(all_cols, colnames(df))
    for (col in miss) {
      df[[col]] <- NA
    }
    df[, all_cols, drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

## ---- Definition-resolution level order (used by the Definition tab) ----- ##
IR_DEFINITION_LEVELS <- c(
  "cells",
  "V",
  "J",
  "V+J",
  "CDR3",
  "V+CDR3",
  "V+J+CDR3"
)

## ---- Count unique entities at each clone-definition resolution --------- ##
## Given the per-cell segment table from ir_parse_segments(), count how many
## distinct entities exist at each of the 7 resolution levels:
##   cells -> V -> J -> V+J -> CDR3 -> V+CDR3 -> V+J+CDR3
## When `group` names a column, counts are computed within each group value.
## Returns a long data.frame: definition (factor, ordered), n, and (if grouped)
## the group column.
ir_definition_counts <- function(seg, group = NULL) {
  if (is.null(seg) || nrow(seg) == 0) {
    return(NULL)
  }
  count_block <- function(df) {
    data.frame(
      definition = factor(
        IR_DEFINITION_LEVELS,
        levels = IR_DEFINITION_LEVELS,
        ordered = TRUE
      ),
      n = c(
        nrow(df),
        length(unique(df$v_gene)),
        length(unique(df$j_gene)),
        length(unique(paste(df$v_gene, df$j_gene, sep = ";"))),
        length(unique(df$cdr3)),
        length(unique(paste(df$v_gene, df$cdr3, sep = ";"))),
        length(unique(df$clone_vjc))
      ),
      stringsAsFactors = FALSE
    )
  }
  if (is.null(group) || !nzchar(group) || !(group %in% colnames(seg))) {
    return(count_block(seg))
  }
  groups <- split(seg, seg[[group]], drop = TRUE)
  out <- do.call(
    rbind,
    lapply(names(groups), function(g) {
      blk <- count_block(groups[[g]])
      blk[[group]] <- g
      blk
    })
  )
  rownames(out) <- NULL
  out
}

## ---- Sharing-class factor levels --------------------------------------- ##
IR_SHARING_LEVELS_3 <- c(
  "Private",
  "Public (within-group)",
  "Public (cross-group)"
)
IR_SHARING_LEVELS_2 <- c("Private", "Public")

## ---- Classify each clonotype by how it is shared ----------------------- ##
## For every distinct clone_vjc, count how many `unit_col` values carry it and
## how many `group_col` values it spans, then label it:
##   Private               : found in exactly 1 unit
##   Public (within-group) : >= 2 units, all in the same group
##   Public (cross-group)  : spans >= 2 groups
## With group_col = NULL there is no group dimension, so it degrades to
## Private / Public (>= 2 units). Returns one row per clonotype: clone_vjc,
## n_units, n_groups (0 when ungrouped), sharing (factor). NA unit/group
## values are ignored when counting, so a stray NA row cannot inflate a
## clonotype into a spurious Public / cross-group classification.
ir_sharing_classify <- function(seg, unit_col, group_col = NULL) {
  if (is.null(seg) || nrow(seg) == 0 || !(unit_col %in% colnames(seg))) {
    return(NULL)
  }
  has_group <- !is.null(group_col) &&
    nzchar(group_col) &&
    group_col %in% colnames(seg)
  by_clone <- split(seg, seg$clone_vjc)
  out <- do.call(
    rbind,
    lapply(names(by_clone), function(cl) {
      df <- by_clone[[cl]]
      n_units <- length(unique(df[[unit_col]][!is.na(df[[unit_col]])]))
      n_groups <- if (has_group) {
        length(unique(df[[group_col]][!is.na(df[[group_col]])]))
      } else {
        0L
      }
      sharing <- if (!has_group) {
        if (n_units <= 1) "Private" else "Public"
      } else if (n_units <= 1) {
        "Private"
      } else if (n_groups >= 2) {
        "Public (cross-group)"
      } else {
        "Public (within-group)"
      }
      data.frame(
        clone_vjc = cl,
        n_units = n_units,
        n_groups = n_groups,
        sharing = sharing,
        stringsAsFactors = FALSE
      )
    })
  )
  lvls <- if (has_group) IR_SHARING_LEVELS_3 else IR_SHARING_LEVELS_2
  out$sharing <- factor(out$sharing, levels = lvls)
  rownames(out) <- NULL
  out
}

## ---- Is the chain a BCR chain? ----------------------------------------- ##
## IGH/IGK/IGL undergo somatic hypermutation, so identical-CDR3 clone calling
## is over-strict for them (one clone can split into near-neighbour variants).
## The Definition / Sharing plots surface this as a subtitle caveat.
ir_is_bcr_chain <- function(chain) {
  is.character(chain) &&
    length(chain) == 1 &&
    !is.na(chain) &&
    any(startsWith(chain, IR_BCR_CHAINS))
}

## ---- BCR caveat line appended to plot subtitles ------------------------ ##
IR_BCR_SHM_CAVEAT <- "BCR: CDR3 not collapsed by SHM; clones may be split."

## ---- Build the Definition (resolution waterfall) ggplot ---------------- ##
## Parses V/J/CDR3 for `chain`, counts entities at the 7 resolution levels
## (optionally within `group_by`), and returns the bar ggplot. Returns NULL
## when there are no cells for the chain (caller renders the empty state).
## Shared by the live renderer and the Example-modal demo.
ir_build_definition_plot <- function(data, chain, group_by = NULL) {
  seg <- ir_parse_segments(data, chain)
  if (is.null(seg) || nrow(seg) == 0) {
    return(NULL)
  }
  df <- ir_definition_counts(seg, group = group_by)
  subtitle <- "V = V gene; J = J gene; CDR3 = complementarity region 3."
  if (ir_is_bcr_chain(chain)) {
    subtitle <- paste(subtitle, IR_BCR_SHM_CAVEAT, sep = "\n")
  }
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = definition, y = n, fill = definition)
  ) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::comma(n)),
      vjust = -0.3,
      size = 3
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0, 0.15)),
      labels = scales::comma
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Unique count",
      title = "Clone definition resolution",
      subtitle = subtitle
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1),
      legend.position = "none"
    )
  if (!is.null(group_by) && nzchar(group_by) && group_by %in% colnames(df)) {
    p <- p +
      ggplot2::facet_wrap(stats::as.formula(paste0("~ `", group_by, "`")))
  }
  p
}

## ---- Friendly display labels for the sharing classes ------------------- ##
## The data layer (ir_sharing_classify) keeps immunology-standard labels
## (Private / Public (within-group) / Public (cross-group)); the plot maps
## them to self-explanatory axis labels. Two-class mode reuses the first two.
IR_SHARING_DISPLAY_LABELS <- c(
  "Private" = "Private (1 sample)",
  "Public (within-group)" = "Shared within group",
  "Public (cross-group)" = "Shared across groups",
  "Public" = "Shared (≥ 2 samples)"
)

## ---- Build the Clone Sharing ggplot ------------------------------------ ##
## Classifies each clonotype (via ir_sharing_classify) and bars the class
## counts, using friendly x-axis labels. Returns NULL on empty data or when
## the unit column is absent. Shared by the live renderer and the demo.
ir_build_sharing_plot <- function(data, chain, unit_col, group_by = NULL) {
  seg <- ir_parse_segments(data, chain)
  if (is.null(seg) || nrow(seg) == 0 || !(unit_col %in% colnames(seg))) {
    return(NULL)
  }
  cls <- ir_sharing_classify(seg, unit_col = unit_col, group_col = group_by)
  if (is.null(cls)) {
    return(NULL)
  }
  counts <- as.data.frame(table(sharing = cls$sharing))
  counts$pct <- counts$Freq / sum(counts$Freq) * 100
  # Map the raw class labels to friendly display labels, preserving order.
  counts$display <- factor(
    IR_SHARING_DISPLAY_LABELS[as.character(counts$sharing)],
    levels = IR_SHARING_DISPLAY_LABELS[levels(counts$sharing)]
  )
  same_col <- !is.null(group_by) &&
    nzchar(group_by) &&
    identical(group_by, unit_col)
  subtitle <- paste(
    "Each clonotype = one receptor.",
    "Private = in a single unit; Shared = in ≥ 2 units."
  )
  if (same_col) {
    subtitle <- paste(
      subtitle,
      "Group and sharing unit are the same column; within/cross is undefined.",
      sep = "\n"
    )
  } else if (is.null(group_by) || !nzchar(group_by)) {
    subtitle <- paste(
      subtitle,
      "No group selected — showing Private / Shared only.",
      sep = "\n"
    )
  }
  if (ir_is_bcr_chain(chain)) {
    subtitle <- paste(subtitle, IR_BCR_SHM_CAVEAT, sep = "\n")
  }
  ggplot2::ggplot(
    counts,
    ggplot2::aes(x = display, y = Freq, fill = display)
  ) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%d (%.1f%%)", Freq, pct)),
      vjust = -0.3,
      size = 3.2
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0, 0.15))
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Number of clonotypes",
      title = "Clonotype sharing",
      subtitle = subtitle
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "none")
}

##----------------------------------------------------------------------------##
## Motif network (Hamming clustering) — ported from tmp/utils/tcr_motif.R,
## de-HLA'd and column-renamed to ir_parse_segments' output (cdr3 / v_gene).
##----------------------------------------------------------------------------##

## ---- Are the motif-network optional deps available? -------------------- ##
has_motif_deps <- function() {
  requireNamespace("stringdist", quietly = TRUE) &&
    requireNamespace("igraph", quietly = TRUE) &&
    requireNamespace("ggraph", quietly = TRUE) &&
    requireNamespace("visNetwork", quietly = TRUE)
}

## ---- Consensus of equal-length seqs; differing positions -> "x" -------- ##
ir_make_consensus <- function(seqs) {
  if (length(seqs) == 1) {
    return(seqs[1])
  }
  m <- do.call(rbind, strsplit(seqs, ""))
  paste0(
    apply(m, 2, function(col) {
      if (length(unique(col)) == 1) col[1] else "x"
    }),
    collapse = ""
  )
}

## ---- Residue(s) a sequence carries at the consensus "x" slots ---------- ##
ir_motif_variable_aa <- function(seq, cons) {
  if (is.na(seq) || is.na(cons)) {
    return("")
  }
  cs <- strsplit(cons, "")[[1]]
  ss <- strsplit(seq, "")[[1]]
  vp <- which(cs == "x")
  if (length(vp) == 0) "" else paste(ss[vp], collapse = "")
}

## ---- Cluster CDR3s within one equal-length bin ------------------------- ##
## `df` rows are all the same cdr3 length. Returns list(df = df + motif cols,
## edges = Hamming==1 pairs).
ir_process_length_group <- function(df, threshold = 1) {
  seqs <- df$cdr3
  n <- length(seqs)
  len_label <- df$cdr3_length[1]

  dist_mat <- stringdist::stringdistmatrix(seqs, seqs, method = "hamming")
  adj <- dist_mat <= threshold
  diag(adj) <- FALSE
  g <- igraph::graph_from_adjacency_matrix(adj, mode = "undirected")
  comps <- igraph::components(g)

  diam <- vapply(
    seq_len(comps$no),
    function(k) {
      members <- which(comps$membership == k)
      if (length(members) < 2) {
        return(0L)
      }
      as.integer(max(dist_mat[members, members]))
    },
    integer(1)
  )
  consensus <- vapply(
    seq_len(comps$no),
    function(k) ir_make_consensus(seqs[which(comps$membership == k)]),
    character(1)
  )

  df$motif_group <- paste0("M", len_label, "_", comps$membership)
  df$motif_size <- comps$csize[comps$membership]
  df$motif_diameter <- diam[comps$membership]
  df$motif_consensus <- consensus[comps$membership]

  edges <- NULL
  if (n > 1) {
    idx <- which(dist_mat == 1 & upper.tri(dist_mat), arr.ind = TRUE)
    if (nrow(idx) > 0) {
      edges <- data.frame(
        from = seqs[idx[, 1]],
        to = seqs[idx[, 2]],
        stringsAsFactors = FALSE
      )
    }
  }
  list(df = df, edges = edges)
}

## ---- Build motif groups over all length (or V+length) bins ------------- ##
## `df` needs columns cdr3, cdr3_length (+ v_gene when by_v). Returns
## list(motif_df = per-CDR3 assignment, edges = Hamming==1 pairs).
ir_build_motif_groups <- function(df, by_v = FALSE, threshold = 1) {
  key_cols <- c("cdr3", "cdr3_length", if (by_v) "v_gene")
  uniq <- df[!duplicated(df[, key_cols, drop = FALSE]), , drop = FALSE]

  split_key <- if (by_v) {
    interaction(uniq$v_gene, uniq$cdr3_length, drop = TRUE)
  } else {
    factor(uniq$cdr3_length)
  }
  results <- lapply(
    split(uniq, split_key),
    ir_process_length_group,
    threshold = threshold
  )

  motif_df <- do.call(rbind, lapply(results, `[[`, "df"))
  edge_list <- lapply(results, `[[`, "edges")
  edge_list <- edge_list[!vapply(edge_list, is.null, logical(1))]
  edges <- if (length(edge_list) == 0) NULL else do.call(rbind, edge_list)

  if (by_v && !is.null(edges)) {
    edge_list2 <- lapply(names(results), function(nm) {
      e <- results[[nm]]$edges
      if (is.null(e)) {
        return(NULL)
      }
      e$v_gene <- results[[nm]]$df$v_gene[1]
      e
    })
    edge_list2 <- edge_list2[!vapply(edge_list2, is.null, logical(1))]
    edges <- if (length(edge_list2) == 0) NULL else do.call(rbind, edge_list2)
  }
  if (by_v) {
    motif_df$motif_group <- paste0(motif_df$v_gene, "::", motif_df$motif_group)
  }
  rownames(motif_df) <- NULL
  list(motif_df = motif_df, edges = edges)
}

## ---- Build the motif igraph from parsed segments ----------------------- ##
## Parses V/J/CDR3 for `chain`, clusters CDR3 by Hamming<=threshold (optionally
## within V gene), drops isolated nodes (degree 0), keeps only clusters with
## > min_size nodes, and returns an igraph whose vertices carry cdr3 / motif_*
## attributes + per-CDR3 metadata (most common value across cells) + clone_count
## (# cells with that CDR3). Returns NULL when no cluster survives.
##
##   min_size      : keep clusters with strictly MORE than this many nodes.
##                   min_size = 1 keeps every connected cluster (>= 2 nodes),
##                   dropping only isolated singletons.
##   show_isolated : when TRUE, keep every CDR3 as a node — isolated CDR3s (no
##                   Hamming neighbour) are drawn as unconnected points, so the
##                   plot shows the full repertoire, not just the motif clusters.
##                   min_size still hides small *connected* clusters.
ir_build_motif_graph <- function(
  data,
  chain,
  threshold = 1,
  by_v = FALSE,
  min_size = 1,
  show_isolated = FALSE
) {
  seg <- ir_parse_segments(data, chain)
  if (is.null(seg) || nrow(seg) == 0) {
    return(NULL)
  }
  seg$cdr3_length <- nchar(seg$cdr3)
  # Per-CDR3 aggregation: clone_count = #cells; metadata cols -> most common.
  meta_cols <- setdiff(
    colnames(seg),
    c(
      "cdr3",
      "cdr3_length",
      "v_gene",
      "j_gene",
      "clone_vjc",
      "barcode",
      "CTgene",
      "CTnt",
      "CTaa",
      "CTstrict",
      "chain"
    )
  )
  mode_val <- function(x) {
    x <- x[!is.na(x)]
    if (length(x) == 0) {
      return(NA)
    }
    names(sort(table(x), decreasing = TRUE))[1]
  }
  # Compact "N types: A (5), B (2)" summary of a categorical vector, count-desc.
  dist_str <- function(x) {
    x <- x[!is.na(x) & nzchar(as.character(x))]
    if (length(x) == 0) {
      return(NA_character_)
    }
    tab <- sort(table(as.character(x)), decreasing = TRUE)
    parts <- paste0(names(tab), " (", as.integer(tab), ")")
    sprintf(
      "%d type%s: %s",
      length(tab),
      if (length(tab) == 1) "" else "s",
      paste(parts, collapse = ", ")
    )
  }
  has_cell_type <- "cell_type" %in% colnames(seg)
  agg <- do.call(
    rbind,
    lapply(split(seg, seg$cdr3), function(d) {
      row <- data.frame(
        cdr3 = d$cdr3[1],
        cdr3_length = d$cdr3_length[1],
        v_gene = mode_val(as.character(d$v_gene)),
        j_gene = mode_val(as.character(d$j_gene)),
        clone_count = nrow(d),
        stringsAsFactors = FALSE
      )
      row$cell_type_dist <- if (has_cell_type) {
        dist_str(d$cell_type)
      } else {
        NA_character_
      }
      for (mc in meta_cols) {
        row[[mc]] <- mode_val(as.character(d[[mc]]))
        # Per-column value distribution, so the tooltip can show how a node's
        # cells split across the active colour column (e.g. "sample_1 (3)").
        row[[paste0(mc, "__dist")]] <- dist_str(d[[mc]])
      }
      row
    })
  )
  rownames(agg) <- NULL

  res <- ir_build_motif_groups(agg, by_v = by_v, threshold = threshold)
  edges <- res$edges
  has_edges <- !is.null(edges) && nrow(edges) > 0
  # Without show_isolated the plot is a similarity network, so a graph with no
  # edges is empty; with show_isolated we still draw every CDR3 as a node.
  if (!has_edges && !isTRUE(show_isolated)) {
    return(NULL)
  }
  vertices <- res$motif_df
  vertices$name <- vertices$cdr3
  vertices <- vertices[, c("name", setdiff(colnames(vertices), "name"))]
  edge_df <- if (has_edges) {
    edges[, c("from", "to")]
  } else {
    data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
  }
  g <- igraph::graph_from_data_frame(
    edge_df,
    vertices = vertices,
    directed = FALSE
  )
  if (!isTRUE(show_isolated)) {
    # Similarity-network view: keep only connected nodes, then keep clusters
    # with strictly more than min_size nodes.
    g <- igraph::induced_subgraph(g, igraph::V(g)[igraph::degree(g) > 0])
    if (igraph::vcount(g) == 0) {
      return(NULL)
    }
    comp <- igraph::components(g)
    keep <- which(comp$csize > min_size)
    if (length(keep) == 0) {
      return(NULL)
    }
    g <- igraph::induced_subgraph(g, igraph::V(g)[comp$membership %in% keep])
  } else {
    # Show-all view: keep every CDR3. min_size still hides small *connected*
    # clusters, but isolated (degree-0) nodes are always kept.
    comp <- igraph::components(g)
    is_isolated <- igraph::degree(g) == 0
    keep_cluster <- comp$csize[comp$membership] > min_size
    keep <- is_isolated | keep_cluster
    g <- igraph::induced_subgraph(g, igraph::V(g)[keep])
  }
  if (igraph::vcount(g) == 0) {
    return(NULL)
  }
  igraph::V(g)$cluster <- igraph::components(g)$membership
  # Total cells parsed for this chain (before any motif filtering) — the
  # denominator for a node's clone-size fraction shown in the tooltip.
  g <- igraph::set_graph_attr(g, "total_cells", nrow(seg))
  g
}

## Above this many clusters, a per-cluster colour legend is just noise (one
## entry per cluster), so the motif plot hides it. Metadata legends are unaffected.
IR_MOTIF_MAX_LEGEND_CLUSTERS <- 10

## Categorical palette for motif node colouring + legend. High-contrast, close
## in spirit to plotly/D3 category colours; nodes and the custom legend share it
## so the swatches always match the drawn points.
IR_MOTIF_PALETTE <- c(
  "#636EFA",
  "#EF553B",
  "#00CC96",
  "#AB63FA",
  "#FFA15A",
  "#19D3F3",
  "#FF6692",
  "#B6E880",
  "#FF97FF",
  "#FECB52"
)

## ---- Draw the motif network with ggraph -------------------------------- ##
## Nodes = CDR3, edges = Hamming-1 neighbours; node size = clone_count. Colour
## by motif cluster (color_by = NULL) or by a metadata column. Cluster consensus
## labels are placed at each component. Returns NULL when the graph is NULL/empty.
## `chain` (optional) drives the BCR SHM caveat in the subtitle.
ir_build_motif_plot <- function(
  graph,
  color_by = NULL,
  chain = NULL,
  show_legend = "show",
  legend_pos = "right"
) {
  if (is.null(graph) || igraph::vcount(graph) == 0) {
    return(NULL)
  }
  set.seed(42)
  lay <- ggraph::create_layout(graph, layout = "fr")

  # A "motif cluster" means CDR3s that actually cluster together (>= 2 nodes).
  # With show_isolated the graph also carries isolated singletons, which are not
  # motifs — they must not inflate the cluster count or get consensus labels.
  cluster_sizes <- table(lay$cluster)
  multi_clusters <- names(cluster_sizes)[cluster_sizes >= 2]
  n_clusters <- length(multi_clusters)

  # Colour aesthetic: cluster (default) or a metadata column present on nodes.
  color_col <- if (
    !is.null(color_by) && nzchar(color_by) && color_by %in% colnames(lay)
  ) {
    color_by
  } else {
    "cluster"
  }

  # A per-cluster colour legend with more levels than the threshold is hundreds
  # of unreadable entries, so it is dropped even when the user asks to show it.
  # Gates on the number of colour LEVELS (every distinct cluster, singletons
  # included), so isolated CDR3s still trigger it. Metadata legends are exempt.
  auto_hidden <- color_col == "cluster" &&
    length(cluster_sizes) > IR_MOTIF_MAX_LEGEND_CLUSTERS

  subtitle <- sprintf(
    "%d CDR3 in %d motif cluster(s). Edge = Hamming distance 1.",
    igraph::vcount(graph),
    n_clusters
  )
  if (auto_hidden) {
    subtitle <- paste(
      subtitle,
      sprintf(
        "Per-cluster legend hidden (%d clusters). Colour by a metadata column to show a legend.",
        length(cluster_sizes)
      ),
      sep = "\n"
    )
  }
  if (ir_is_bcr_chain(chain)) {
    subtitle <- paste(subtitle, IR_BCR_SHM_CAVEAT, sep = "\n")
  }

  # Per-cluster consensus labels, placed above each component. Only multi-node
  # clusters get a label; an isolated singleton's "consensus" is just itself,
  # so labelling hundreds of them buries the plot.
  y_pad <- if (diff(range(lay$y)) > 0) diff(range(lay$y)) * 0.05 else 0.5
  lay_multi <- lay[
    as.character(lay$cluster) %in% multi_clusters,
    ,
    drop = FALSE
  ]
  cl_lab <- if (nrow(lay_multi) == 0) {
    data.frame(
      x = numeric(0),
      y = numeric(0),
      label = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    do.call(
      rbind,
      lapply(split(lay_multi, lay_multi$cluster), function(d) {
        data.frame(
          x = mean(d$x),
          y = max(d$y) + y_pad,
          label = d$motif_consensus[1],
          stringsAsFactors = FALSE
        )
      })
    )
  }

  p <- ggraph::ggraph(lay) +
    ggraph::geom_edge_link(colour = "grey60", alpha = 0.6) +
    ggraph::geom_node_point(
      ggplot2::aes(
        size = clone_count,
        colour = factor(.data[[color_col]])
      ),
      alpha = 0.85
    ) +
    ggplot2::scale_size_continuous(name = "Clone size", range = c(2, 9)) +
    ggplot2::labs(
      title = "CDR3 motif network",
      subtitle = subtitle,
      colour = if (color_col == "cluster") "Motif cluster" else color_by
    ) +
    ggplot2::geom_label(
      data = cl_lab,
      ggplot2::aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      size = 3,
      fill = "grey95",
      linewidth = 0.2
    ) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      plot.subtitle = ggplot2::element_text(hjust = 0.5, size = 9),
      # Legend visibility precedence:
      #  1. user's Show/Hide control: "hide" always wins.
      #  2. auto-hide an unreadable per-cluster legend (see auto_hidden above).
      #  3. otherwise place it where the user asked (legend_pos).
      legend.position = if (identical(show_legend, "hide") || auto_hidden) {
        "none"
      } else {
        legend_pos
      }
    )
  p
}

## ---- Build interactive motif network (visNetwork) --------------------- ##
## igraph -> list(nodes, edges, ...) for visNetwork. Node size follows
## clone_count; colour follows cluster (default) or a metadata column; the HTML
## tooltip (title) shows CDR3, clone size, cell-type distribution, chain, and
## V/J genes. Returns NULL for a NULL/empty graph (same contract as
## ir_build_motif_plot). Legend suppression reuses IR_MOTIF_MAX_LEGEND_CLUSTERS.
ir_build_motif_visnet <- function(
  graph,
  color_by = NULL,
  chain = NULL,
  show_legend = "show",
  legend_pos = "right"
) {
  if (is.null(graph) || igraph::vcount(graph) == 0) {
    return(NULL)
  }
  va <- igraph::vertex_attr(graph)
  n <- igraph::vcount(graph)

  # Colour aesthetic: cluster (default) or a metadata column present on nodes.
  color_col <- if (
    !is.null(color_by) && nzchar(color_by) && color_by %in% names(va)
  ) {
    color_by
  } else {
    "cluster"
  }

  get_attr <- function(nm) if (nm %in% names(va)) va[[nm]] else rep(NA, n)
  cdr3 <- get_attr("name")
  clone_count <- get_attr("clone_count")
  v_gene <- get_attr("v_gene")
  j_gene <- get_attr("j_gene")
  cell_dist <- get_attr("cell_type_dist")
  cdr3_len <- get_attr("cdr3_length")

  # Explicit colour per level so the nodes and the legend share one palette
  # (vis's auto group colouring is opaque and can't be mirrored in a custom
  # legend). Levels are ordered: cluster levels numerically, others by first
  # appearance. Colours cycle through IR_MOTIF_PALETTE.
  group_raw <- as.character(get_attr(color_col))
  levels_ord <- if (color_col == "cluster") {
    as.character(sort(unique(suppressWarnings(as.numeric(group_raw)))))
  } else {
    unique(group_raw[!is.na(group_raw)])
  }
  levels_ord <- levels_ord[!is.na(levels_ord)]
  pal <- IR_MOTIF_PALETTE
  level_colors <- setNames(
    pal[((seq_along(levels_ord) - 1) %% length(pal)) + 1],
    levels_ord
  )
  node_color <- unname(level_colors[group_raw])
  node_color[is.na(node_color)] <- "grey70"

  # Each real node is labelled with only its VARIABLE residues — the letters it
  # carries at the consensus 'x' positions (e.g. consensus CASSxTGNEQFF, CDR3
  # CASSLTGNEQFF -> "L"). This keeps the differing residue next to every point
  # without repeating the shared backbone. Singletons (no consensus 'x') get no
  # label; the full CDR3 stays in the tooltip.
  topo_cluster <- as.character(get_attr("cluster"))
  consensus <- get_attr("motif_consensus")
  node_label <- vapply(
    seq_len(n),
    function(i) ir_motif_variable_aa(cdr3[i], consensus[i]),
    character(1)
  )

  # HTML tooltip. Lines with a missing value are dropped. Built after color_col
  # so the active colour column's per-node distribution can be shown.
  esc <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }
  has_chain <- !is.null(chain) &&
    length(chain) == 1 &&
    !is.na(chain) &&
    nzchar(chain)
  deg <- igraph::degree(graph)
  csize_tab <- table(topo_cluster)
  cluster_size <- as.integer(csize_tab[as.character(topo_cluster)])
  total_cells <- tryCatch(
    igraph::graph_attr(graph, "total_cells"),
    error = function(e) NULL
  )
  if (length(total_cells) != 1 || is.na(total_cells)) {
    total_cells <- NA_real_
  }
  # Distribution of the active colour column across a node's cells (metadata
  # colouring only). Skipped for cluster colouring (its identity is the "Motif
  # cluster" line) and for cell_type (already shown by the cell-type line).
  color_dist <- if (!color_col %in% c("cluster", "cell_type")) {
    get_attr(paste0(color_col, "__dist"))
  } else {
    rep(NA_character_, n)
  }
  titles <- vapply(
    seq_len(n),
    function(i) {
      frac <- if (
        !is.na(total_cells) && total_cells > 0 && !is.na(clone_count[i])
      ) {
        sprintf(" (%.1f%%)", 100 * clone_count[i] / total_cells)
      } else {
        ""
      }
      lines <- c(
        sprintf("<b>%s</b>", esc(cdr3[i])),
        if (!is.na(cdr3_len[i])) {
          sprintf("Length: %s aa", esc(cdr3_len[i]))
        } else {
          NULL
        },
        if (!is.na(topo_cluster[i]) && !is.na(consensus[i])) {
          sprintf(
            "Motif cluster %s &middot; %s",
            esc(topo_cluster[i]),
            esc(consensus[i])
          )
        } else {
          NULL
        },
        if (nzchar(node_label[i])) {
          sprintf("Variable residue: %s", esc(node_label[i]))
        } else {
          NULL
        },
        sprintf("Clone size: %s%s", esc(clone_count[i]), frac),
        sprintf(
          "Neighbours: %s &middot; cluster size %s",
          esc(deg[i]),
          esc(cluster_size[i])
        ),
        if (!is.na(cell_dist[i])) esc(cell_dist[i]) else NULL,
        if (!is.na(color_dist[i])) {
          sprintf("%s: %s", esc(color_col), esc(color_dist[i]))
        } else {
          NULL
        },
        if (has_chain) sprintf("Chain: %s", esc(chain)) else NULL,
        sprintf("V/J: %s / %s", esc(v_gene[i]), esc(j_gene[i]))
      )
      paste(lines, collapse = "<br>")
    },
    character(1)
  )

  nodes <- data.frame(
    id = seq_len(n),
    label = node_label,
    value = as.numeric(clone_count),
    group = group_raw,
    color = node_color,
    title = titles,
    # `cl` (topological cluster id) lets the client place each consensus title
    # over its cluster's centroid after layout settles. A node's role is read
    # from `shape` ("dot" = real point, "text" = title), not from `cl`.
    cl = as.integer(topo_cluster),
    # Real points show their variable-residue letter just ABOVE the dot (a small
    # dot can't hold text inside), dark and bold so it reads against the canvas.
    shape = "dot",
    # Point AREA scales with clone_count via `value` + visNodes(scaling); `size`
    # is left NA on real points so it does not override the value-based scaling.
    size = NA_real_,
    font.size = 18,
    font.color = "#2a3f5f",
    font.vadjust = -22,
    # Real points are laid out by physics.
    physics = TRUE,
    stringsAsFactors = FALSE
  )

  el <- igraph::as_edgelist(graph, names = FALSE)
  edges <- if (nrow(el) == 0) {
    data.frame(from = integer(0), to = integer(0), stringsAsFactors = FALSE)
  } else {
    data.frame(from = el[, 1], to = el[, 2], stringsAsFactors = FALSE)
  }

  # Per-cluster CONSENSUS title: one extra text-only node per multi-node
  # cluster. It is physics-free (physics = FALSE) and carries no edge; the
  # client pins it above its cluster's centroid once the layout stabilises
  # (see the visEvents "stabilized" handler), so it never drifts or overlaps.
  title_id <- n
  for (cl in sort(unique(as.integer(topo_cluster)))) {
    idx <- which(as.integer(topo_cluster) == cl)
    if (length(idx) < 2) {
      next # singleton: no cluster title
    }
    rep_i <- idx[which.max(as.numeric(clone_count[idx]))]
    lab <- consensus[rep_i]
    if (is.na(lab) || !nzchar(as.character(lab))) {
      next
    }
    title_id <- title_id + 1L
    nodes <- rbind(
      nodes,
      data.frame(
        id = title_id,
        label = as.character(lab),
        # Title nodes are text only: no value (kept out of size scaling) and a
        # fixed nominal size so they never participate in the clone-size scale.
        value = NA_real_,
        group = NA_character_,
        color = "#2a3f5f",
        title = NA_character_,
        # A title's `cl` names the cluster it labels, so the client can find
        # that cluster's points and centre the title above them.
        cl = cl,
        shape = "text",
        size = 1,
        font.size = 22,
        font.color = "#2a3f5f",
        font.vadjust = 0,
        physics = FALSE,
        stringsAsFactors = FALSE
      )
    )
  }

  # Suppress a legend that would be hundreds of unreadable cluster entries, or
  # when the user asked to hide it. Mirrors ir_build_motif_plot's gate.
  n_levels <- length(levels_ord)
  hide_legend <- identical(show_legend, "hide") ||
    (color_col == "cluster" && n_levels > IR_MOTIF_MAX_LEGEND_CLUSTERS)

  # plotly-style legend: a titled, right-hand column of coloured dots + labels.
  # Cluster levels read as "Cluster N"; metadata levels keep their own value.
  legend_title <- if (color_col == "cluster") "Motif cluster" else color_col
  legend_labels <- if (color_col == "cluster") {
    paste("Cluster", levels_ord)
  } else {
    levels_ord
  }
  legend <- data.frame(
    label = legend_labels,
    color = unname(level_colors[levels_ord]),
    shape = "dot",
    stringsAsFactors = FALSE
  )

  # Size legend: node area encodes clone_count, so surface a few representative
  # clone sizes (min / median / max of the real points). Only the VALUES are
  # returned here — the swatch radius is read back from vis on the client after
  # layout, so the legend circles exactly match how vis actually draws the
  # points (a small clone-size range no longer blows up into a tiny-vs-huge
  # pair). Always shown; a single-value repertoire collapses to one swatch.
  cc <- as.numeric(clone_count)
  cc <- cc[is.finite(cc)]
  size_legend <- NULL
  if (length(cc) > 0) {
    lo <- min(cc)
    hi <- max(cc)
    reps <- if (hi > lo) {
      sort(unique(c(lo, round(stats::median(cc)), hi)))
    } else {
      lo
    }
    size_legend <- data.frame(value = reps, stringsAsFactors = FALSE)
  }

  list(
    nodes = nodes,
    edges = edges,
    color_col = color_col,
    hide_legend = hide_legend,
    legend = legend,
    legend_title = legend_title,
    size_legend = size_legend
  )
}
