# ============================================================================
# Display helpers shared by the HLA motif Shiny module
# ============================================================================

#' Generate a stable distinct colour for every categorical level
#'
#' The first ten levels use the page's established palette. Larger sets switch
#' to an HCL palette rather than cycling colours and making different categories
#' visually indistinguishable.
#'
#' @param levels Character vector of categorical levels in display order.
#' @return Named character vector `level -> colour`.
#' @importFrom htmlwidgets JS
#' @keywords internal
hla_distinct_colors <- function(levels) {
  levels <- unique(as.character(levels))
  if (length(levels) == 0) {
    return(stats::setNames(character(0), character(0)))
  }
  base_palette <- c(
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
  colours <- if (length(levels) <= length(base_palette)) {
    base_palette[seq_along(levels)]
  } else {
    grDevices::hcl.colors(length(levels), palette = "Dynamic")
  }
  stats::setNames(colours, levels)
}
