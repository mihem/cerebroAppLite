##----------------------------------------------------------------------------##
## Tab: Trajectory
##
## Select method and name.
##----------------------------------------------------------------------------##

##----------------------------------------------------------------------------##
## UI element to set layout for selection of method and name, which are split
## because the names of available trajectories depends on which method is
## selected. If no method is available, show message that data is missing.
##----------------------------------------------------------------------------##

output[["trajectory_select_method_and_name_UI"]] <- renderUI({
  ## currently, only trajectories from monocle2 are supported
  available_methods <- getMethodsForTrajectories()
  available_methods <- available_methods[available_methods %in% c('monocle2')]

  if (length(available_methods) == 0) {
    textOutput("trajectory_missing")
  } else if (length(available_methods) > 0) {
    tagList(
      uiOutput("trajectory_selected_method_UI"),
      uiOutput("trajectory_selected_name_UI")
    )
  }
})

##----------------------------------------------------------------------------##
## UI element to select from which method the results should be shown.
##----------------------------------------------------------------------------##

output[["trajectory_selected_method_UI"]] <- renderUI({
  ## currently, only trajectories from monocle2 are supported
  available_methods <- getMethodsForTrajectories()
  available_methods <- available_methods[available_methods %in% c('monocle2')]

  selectInput(
    "trajectory_selected_method",
    label = "Choose a method",
    choices = available_methods,
    width = "100%"
  )
})

##----------------------------------------------------------------------------##
## UI element to select which trajectory (name) should be shown.
##----------------------------------------------------------------------------##

output[["trajectory_selected_name_UI"]] <- renderUI({
  req(
    input[["trajectory_selected_method"]]
  )
  selectInput(
    "trajectory_selected_name",
    label = "Choose a trajectory",
    choices = getNamesOfTrajectories(input[[
      "trajectory_selected_method"
    ]]),
    width = "100%"
  )
})

##----------------------------------------------------------------------------##
## Alternative text message if data is missing.
##----------------------------------------------------------------------------##

output[["trajectory_missing"]] <- renderText({
  "No trajectories available to display."
})
