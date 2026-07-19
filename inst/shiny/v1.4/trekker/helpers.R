##----------------------------------------------------------------------------##
## Tab: Trekker — pure helpers.
##
## Split out of server.R so they can be unit-tested without a running Shiny
## session: this file is sourced at runtime by trekker/server.R (bare-name calls,
## works packaged or via runApp('inst')) and by
## tests/testthat/helper-trekker-helpers.R. Keep it side-effect free — plain
## functions of their arguments only, no `input` / `output` / `data_set`.
##----------------------------------------------------------------------------##

#' Genes offered first in the Trekker gene picker.
#'
#' The upstream Moran's I top genes plus canonical mouse-brain markers, restricted
#' to genes actually measured in the object (the full ~21k measured genes stay
#' selectable because the picker searches the whole list).
#'
#' @param tk The Trekker slot (a list); `tk$moran` is a list of `list(gene = ...)`.
#' @param gene_names Character vector of measured gene names (matrix row names).
#' @return Character vector of suggested genes, all present in `gene_names`.
trekker_gene_suggest <- function(tk, gene_names) {
  markers <- c(
    "Snap25",
    "Slc17a7",
    "Gad1",
    "Gad2",
    "Plp1",
    "Mbp",
    "Aqp4",
    "Gfap",
    "Cx3cr1",
    "C1qa",
    "Csf1r",
    "Pdgfra",
    "Prox1"
  )
  moran_genes <- if (length(tk$moran)) {
    vapply(tk$moran, function(m) m$gene, character(1))
  } else {
    character(0)
  }
  cand <- unique(c(moran_genes, markers))
  cand[cand %in% gene_names]
}

#' Numeric, non-constant per-cell meta columns eligible to colour the map.
#'
#' Any existing per-cell analysis output the object carries — pseudotime, a
#' signature/module score, velocity magnitude, a signaling score — can colour the
#' physical map with no page change. Constant and non-numeric columns are dropped.
#'
#' @param meta A data frame / list of per-cell meta columns (e.g. `getMetaData()`).
#' @return Character vector of column names.
trekker_numeric_meta_cols <- function(meta) {
  if (is.null(meta) || length(meta) == 0) {
    return(character(0))
  }
  names(meta)[vapply(
    meta,
    function(x) is.numeric(x) && length(unique(x[!is.na(x)])) > 1,
    logical(1)
  )]
}
