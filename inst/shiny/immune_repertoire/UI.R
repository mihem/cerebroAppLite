##----------------------------------------------------------------------------##
## Tab: Immune Repertoire (unified TCR/BCR)
##----------------------------------------------------------------------------##

tab_immune_repertoire <- tabItem(
  tabName = "immune_repertoire",
  fluidRow(
    cerebroBox(
      title = boxTitle("Immune Repertoire settings"),
      content = shinycssloaders::withSpinner(uiOutput("ir_settings_UI"))
    )
  ),
  fluidRow(
    cerebroBox(
      title = boxTitle("Immune Repertoire visualizations"),
      content = tagList(
        uiOutput("ir_help_panel"),
        shinycssloaders::withSpinner(uiOutput("ir_visualizations_UI"))
      )
    )
  )
)
