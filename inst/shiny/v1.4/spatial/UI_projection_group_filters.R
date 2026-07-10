##----------------------------------------------------------------------------##
## UI elements to set group filters for the spatial projection.
##
## Implementation lives in inst/shiny/module/group_filters/group_filters_widget.R.
##----------------------------------------------------------------------------##

registerGroupFiltersUI(
  output,
  "spatial_projection",
  getGroups = getGroups,
  getGroupLevels = getGroupLevels
)

registerGroupFiltersInfo(
  input,
  "spatial_projection",
  title = "Group filters for projection",
  text = HTML(
    "The elements in this panel allow you to select which cells should be plotted based on the group(s) they belong to. For each grouping variable, you can activate or deactivate group levels. Only cells that are pass all filters (for each grouping variable) are shown in the projection."
  )
)
