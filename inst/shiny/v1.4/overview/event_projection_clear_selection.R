##----------------------------------------------------------------------------##
## Clear selection button event handler.
##----------------------------------------------------------------------------##
observeEvent(input[["overview_projection_clear_selection"]], {
  ## Call the shared JS clearSelection() for this plot.
  shinyjs::js$overviewClearSelection()
})

##----------------------------------------------------------------------------##
## Zoom-to-selection button event handler.
##----------------------------------------------------------------------------##
## Frames the selected region at the true data aspect ratio (no stretch) via the
## shared JS. Returning to the full view uses the existing reset/autorange path.
observeEvent(input[["overview_projection_zoom_to_selection"]], {
  shinyjs::js$overviewZoomToSelection()
})

##----------------------------------------------------------------------------##
## Reflect the zoom state on the button: filled "Reset zoom" while zoomed in,
## default "Zoom to selection" otherwise. The JS toggle reports the state under
## <plot_id>_zoom_state.
##----------------------------------------------------------------------------##
observeEvent(
  input[["overview_projection_zoom_state"]],
  {
    zoomed <- isTRUE(input[["overview_projection_zoom_state"]])
    shinyjs::toggleClass(
      id = "overview_projection_zoom_to_selection",
      class = "is-zoomed",
      condition = zoomed
    )
    updateActionButton(
      session,
      "overview_projection_zoom_to_selection",
      label = if (zoomed) "Reset zoom" else "Zoom to selection",
      icon = if (zoomed) {
        icon("magnifying-glass-minus")
      } else {
        icon("magnifying-glass-plus")
      }
    )
  },
  ignoreInit = TRUE
)

##----------------------------------------------------------------------------##
## Toggle visibility of the selection action buttons.
##----------------------------------------------------------------------------##
## Follows the persistent selection (not Plotly's volatile plotly_selected
## event), so the buttons stay visible across plot parameter changes and are
## hidden only when the selection is actually cleared.
observe({
  selected <- overview_projection_selected_cells()
  if (!is.null(selected) && nrow(selected) > 0) {
    shinyjs::show("overview_projection_clear_selection")
    shinyjs::show("overview_projection_zoom_to_selection")
  } else {
    shinyjs::hide("overview_projection_clear_selection")
    shinyjs::hide("overview_projection_zoom_to_selection")
  }
})
