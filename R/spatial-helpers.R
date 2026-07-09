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
