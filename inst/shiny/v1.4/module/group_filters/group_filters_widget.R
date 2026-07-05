##----------------------------------------------------------------------------##
## Shared group-filters widget for projection-style tabs.
##
## overview / spatial / gene_expression each used to ship a near-byte-identical
## UI_projection_group_filters.R file (~90 lines) — same renderUI, same
## pickerInput loop, same outputOptions, same observeEvent on the info button.
## The only diffs were the input/output ID prefix and the info-modal text.
##
## Two helpers below take a `prefix` and the tab's getGroups / getGroupLevels
## closures (passed explicitly so this file does not need to be sourced inside
## the caller's environment).
##----------------------------------------------------------------------------##

#' Register the group-filters renderUI for a projection-style tab.
#'
#' Creates `output[[paste0(prefix, "_group_filters_UI")]]` which renders one
#' shinyWidgets::pickerInput per grouping variable. Each picker's inputId is
#' `<prefix>_group_filter_<groupName>` so existing downstream observers
#' (cells_to_show etc.) continue to read the same input names.
#'
#' @param output The Shiny output object from the server function.
#' @param prefix Tab-specific prefix, e.g. "overview_projection",
#'        "spatial_projection", "expression_projection".
#' @param getGroups Closure returning a character vector of grouping variable
#'        names. Pass the caller's own getGroups() defined in
#'        utility_functions.R.
#' @param getGroupLevels Closure mapping a group name to its levels.
registerGroupFiltersUI <- function(output, prefix, getGroups, getGroupLevels) {
  output_id <- paste0(prefix, "_group_filters_UI")

  output[[output_id]] <- shiny::renderUI({
    group_filters <- list()
    for (i in getGroups()) {
      group_filters[[i]] <- shinyWidgets::pickerInput(
        paste0(prefix, "_group_filter_", i),
        label = i,
        choices = getGroupLevels(i),
        selected = getGroupLevels(i),
        options = list("actions-box" = TRUE),
        multiple = TRUE
      )
    }
    group_filters
  })

  ## ensure rendered even when the surrounding cerebroBox is collapsed
  shiny::outputOptions(output, output_id, suspendWhenHidden = FALSE)
}

#' Register the info-button modal for the group-filters panel.
#'
#' Wires `input[[paste0(prefix, "_group_filters_info")]]` to a modalDialog.
#' The text differs per tab so it is passed in.
#'
#' @param input The Shiny input object from the server function.
#' @param prefix Same prefix as registerGroupFiltersUI.
#' @param title Modal title.
#' @param text Modal body (typically `HTML("...")`).
registerGroupFiltersInfo <- function(input, prefix, title, text) {
  info_id <- paste0(prefix, "_group_filters_info")
  shiny::observeEvent(input[[info_id]], {
    shiny::showModal(shiny::modalDialog(
      text,
      title = title,
      easyClose = TRUE,
      footer = NULL,
      size = "l"
    ))
  })
}
