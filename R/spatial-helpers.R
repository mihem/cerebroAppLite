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
