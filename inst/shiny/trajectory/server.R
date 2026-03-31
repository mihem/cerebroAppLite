##----------------------------------------------------------------------------##
## Tab: Trajectory
##----------------------------------------------------------------------------##

##----------------------------------------------------------------------------##
## Reactive to fetch trajectory data
##----------------------------------------------------------------------------##
trajectory_data_reactive <- reactive({
  req(
    input[["trajectory_selected_method"]],
    input[["trajectory_selected_name"]]
  )
  getTrajectory(
    input[["trajectory_selected_method"]],
    input[["trajectory_selected_name"]]
  )
})

source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/select_method_and_name.R"), local = TRUE)
source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/projection.R"), local = TRUE)
source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/selected_cells_table.R"), local = TRUE)
source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/distribution_along_pseudotime.R"), local = TRUE)
source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/states_by_group.R"), local = TRUE)
source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/trajectory/expression_metrics.R"), local = TRUE)
