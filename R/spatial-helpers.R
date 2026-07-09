#' Resolve a per-dataset spatial background-image preset
#'
#' The spatial tab seeds the histology overlay's move / scale / flip from
#' per-dataset `spatial_images_*` presets configured in `Cerebro.options`, so an
#' app can ship a pre-aligned overlay. This helper is the single lookup shared by
#' the UI seed, the plot parameters, and Reset: given the options list, the
#' available crb files (a named vector mapping file path -> dataset label) and
#' the currently selected file, it returns the preset value for the current
#' dataset, or `fallback` when no applicable preset exists.
#'
#' A preset only applies when it is a length-1, non-NA scalar keyed by the
#' current dataset's label; anything else (missing option, unselected dataset,
#' unmatched file, NA, or a non-scalar value) yields `fallback`.
#'
#' @param option_name Name of the option in `options`, e.g.
#'   `"spatial_images_offset_x"`.
#' @param fallback Value returned when no applicable preset exists (the identity
#'   value: 0 for move, 1 for scale, FALSE for flip).
#' @param options The `Cerebro.options` list (or `NULL`).
#' @param crb_files Named vector of available files (`file_path` values, dataset
#'   labels as names).
#' @param selected The currently selected file path (or `NULL`).
#'
#' @return The resolved preset value, or `fallback`.
#' @keywords internal
#' @noRd
resolve_spatial_image_preset <- function(
  option_name,
  fallback,
  options,
  crb_files,
  selected
) {
  if (
    is.null(options) ||
      is.null(options[[option_name]]) ||
      is.null(crb_files) ||
      is.null(selected)
  ) {
    return(fallback)
  }
  idx <- which(crb_files == selected)
  if (length(idx) == 0) {
    return(fallback)
  }
  current_name <- names(crb_files)[idx[1]]
  if (
    is.null(current_name) ||
      !(current_name %in% names(options[[option_name]]))
  ) {
    return(fallback)
  }
  val <- options[[option_name]][[current_name]]
  if (is.null(val) || length(val) != 1 || is.na(val)) fallback else val
}

#' Turn a hand-tuned overlay alignment into pasteable Cerebro.options preset code
#'
#' After a user nudges the histology overlay into place in the Spatial tab, this
#' produces the `spatial_images_*` preset lines to drop into an app's
#' `Cerebro.options` so the dataset opens pre-aligned. Only the six supported
#' options (offset x/y, scale x/y, flip x/y) are emitted, and only when they
#' differ from the identity (0 move, 1 scale, no flip), so a clean alignment
#' yields a short snippet. Rotation has no preset option and is intentionally
#' not emitted.
#'
#' @param label Dataset label (the name used in `crb_file_to_load`), quoted
#'   verbatim as the preset's key.
#' @param offset_x,offset_y Move in data units.
#' @param scale_x,scale_y Scale about centre.
#' @param flip_x,flip_y Logical mirror flags.
#'
#' @return A single string: the preset lines, or a `##`-commented note when the
#'   alignment is the identity (nothing to persist).
#' @keywords internal
#' @noRd
format_spatial_preset_code <- function(
  label,
  offset_x,
  offset_y,
  scale_x,
  scale_y,
  flip_x,
  flip_y
) {
  key <- function(value) paste0('c("', label, '" = ', value, ")")
  lines <- character(0)
  add <- function(option_name, value) {
    lines[[length(lines) + 1]] <<- paste0(
      '"',
      option_name,
      '" = ',
      key(value)
    )
  }
  if (isTRUE(offset_x != 0)) {
    add("spatial_images_offset_x", offset_x)
  }
  if (isTRUE(offset_y != 0)) {
    add("spatial_images_offset_y", offset_y)
  }
  if (isTRUE(scale_x != 1)) {
    add("spatial_images_scale_x", scale_x)
  }
  if (isTRUE(scale_y != 1)) {
    add("spatial_images_scale_y", scale_y)
  }
  if (isTRUE(flip_x)) {
    add("spatial_images_flip_x", "TRUE")
  }
  if (isTRUE(flip_y)) {
    add("spatial_images_flip_y", "TRUE")
  }
  if (length(lines) == 0) {
    return(
      "## No adjustments to persist — the overlay is at its default alignment."
    )
  }
  paste(lines, collapse = ",\n")
}

#' Convex hull of each spatial group, for region outlines
#'
#' Given per-point coordinates and a group label per point, compute the convex
#' hull of each group as a closed polygon (the first vertex repeated at the end),
#' so the categorical spatial plot can outline each colour group's tissue region.
#' Points with an NA x or y are ignored. A group is dropped when it has fewer
#' than three distinct, non-collinear points, i.e. when it encloses no area and
#' so has no meaningful outline.
#'
#' @param x,y Numeric coordinate vectors (same length).
#' @param group Group label per point (same length as `x`/`y`).
#'
#' @return A named list keyed by group; each element is a list with numeric `x`
#'   and `y` vertex vectors describing the closed hull. Groups without a usable
#'   hull are omitted; an all-empty input yields an empty list.
#' @keywords internal
#' @noRd
compute_group_hulls <- function(x, y, group) {
  result <- list()
  if (length(x) == 0) {
    return(result)
  }
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]
  y <- y[ok]
  group <- group[ok]
  for (g in unique(group)) {
    in_g <- group == g
    gx <- x[in_g]
    gy <- y[in_g]
    if (length(gx) < 3) {
      next
    }
    ## chull needs at least 3 non-collinear points; collinear input returns a
    ## degenerate hull (< 3 vertices) that encloses no area — skip it.
    idx <- grDevices::chull(gx, gy)
    if (length(idx) < 3) {
      next
    }
    ## close the ring by repeating the first vertex
    idx <- c(idx, idx[1])
    result[[g]] <- list(x = gx[idx], y = gy[idx])
  }
  result
}

#' Blend up to three genes' expression onto RGB channels
#'
#' Maps each gene's expression onto one colour channel (red / green / blue) so a
#' cell's colour blends the genes it expresses — spatial co-expression reads as a
#' mixed hue. Each channel is normalised independently to its own maximum, so it
#' reports intensity relative to that gene's own range rather than across genes.
#' A `NULL` channel contributes 0; `NA` expression is treated as 0 for that cell.
#' A channel whose values are all equal and non-zero is treated as fully
#' expressed (avoids dividing by a zero range); an all-zero channel stays 0.
#'
#' @param r,g,b Numeric expression vectors (same length), or `NULL` for an
#'   unused channel.
#'
#' @return A character vector of `"rgb(R,G,B)"` strings, one per cell.
#' @keywords internal
#' @noRd
blend_genes_to_rgb <- function(r = NULL, g = NULL, b = NULL) {
  ## Determine the cell count from whichever channel is supplied.
  n <- max(length(r), length(g), length(b))
  channel <- function(values) {
    if (is.null(values)) {
      return(rep(0L, n))
    }
    values[is.na(values)] <- 0
    mx <- max(values)
    if (mx <= 0) {
      return(rep(0L, n))
    }
    as.integer(round(values / mx * 255))
  }
  rc <- channel(r)
  gc <- channel(g)
  bc <- channel(b)
  paste0("rgb(", rc, ",", gc, ",", bc, ")")
}

#' Moran's I spatial autocorrelation for a gene
#'
#' Scores whether a gene's expression is spatially clustered: values near +1 mean
#' high and low cells segregate into spatial patches, near 0 means a random
#' spatial pattern, and negative means neighbouring cells tend to be dissimilar.
#' Spatial weights are binary k-nearest-neighbour: each cell's `k` closest
#' neighbours (Euclidean distance) count 1, all others 0. Computed via
#' \code{ape::Moran.I} on that weight matrix.
#'
#' Cells with NA expression are dropped first. Zero-variance input returns 0 (no
#' signal, rather than NaN). Fewer than `k + 1` cells returns NA (can't form the
#' neighbourhood).
#'
#' @param x,y Coordinate vectors (same length).
#' @param values Per-cell expression (same length as `x`/`y`).
#' @param k Number of nearest neighbours for the weight matrix.
#'
#' @return The Moran's I statistic (scalar in [-1, 1]), or NA when undefined.
#' @keywords internal
#' @noRd
morans_i <- function(x, y, values, k = 6) {
  ok <- !is.na(x) & !is.na(y) & !is.na(values)
  x <- x[ok]
  y <- y[ok]
  values <- values[ok]
  n <- length(values)
  if (n < k + 1) {
    return(NA_real_)
  }
  if (stats::sd(values) == 0) {
    return(0)
  }
  ## Euclidean distance matrix, then a binary weight for each cell's k nearest
  ## neighbours (excluding itself). O(n^2); callers down-sample large inputs.
  dmat <- as.matrix(stats::dist(cbind(x, y)))
  weight <- matrix(0, n, n)
  for (i in seq_len(n)) {
    di <- dmat[i, ]
    di[i] <- Inf # never neighbour itself
    nn <- order(di)[seq_len(k)]
    weight[i, nn] <- 1
  }
  res <- ape::Moran.I(values, weight)
  res$observed
}
