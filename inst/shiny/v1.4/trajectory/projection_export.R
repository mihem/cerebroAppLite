##----------------------------------------------------------------------------##
## Export trajectory projection to a downloadable vector PDF.
##
## Security (S2): the plot is rendered straight into the download stream (a
## per-session tempfile Shiny manages) and delivered to the browser, never to a
## server-side path chosen through a shinyFiles save dialog. Nothing is written
## to the host filesystem outside the session temp dir, so a generated bundle
## stays safe to serve to untrusted users.
##----------------------------------------------------------------------------##
output[["trajectory_projection_export"]] <- downloadHandler(
  filename = function() {
    paste0("trajectory_", format(Sys.Date()), ".pdf")
  },
  content = function(file) {
    req(
      trajectory_selection_ok(),
      input[["trajectory_point_color"]],
      input[["trajectory_percentage_cells_to_show"]],
      input[["trajectory_point_size"]],
      input[["trajectory_point_opacity"]]
    )

    ## ggplot2 functions are necessary to create the plot
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
      shinyWidgets::sendSweetAlert(
        session = session,
        title = "Error!",
        text = "The 'ggplot2' package is required to export trajectory plots.",
        type = "error"
      )
      stop("ggplot2 is required to export trajectory plots.")
    }

    trajectory_data <- getTrajectory(
      input[["trajectory_selected_method"]],
      input[["trajectory_selected_name"]]
    )

    ## build data frame with data
    cells_df <- mergeTrajectoryWithMetaData(trajectory_data) %>%
      dplyr::filter(!is.na(pseudotime))

    ## randomly remove cells (if necessary)
    cells_df <- randomlySubsetCells(
      cells_df,
      input[["trajectory_percentage_cells_to_show"]]
    )

    ## put rows in random order
    cells_df <- cells_df[sample(seq_len(nrow(cells_df))), ]

    ## start building the plot
    plot <- ggplot() +
      geom_point(
        data = cells_df,
        aes(
          x = .data[[colnames(cells_df)[1]]],
          y = .data[[colnames(cells_df)[2]]],
          fill = .data[[input[["trajectory_point_color"]]]]
        ),
        shape = 21,
        size = input[["trajectory_point_size"]] / 3,
        stroke = 0.2,
        color = "#c4c4c4",
        alpha = input[["trajectory_point_opacity"]]
      ) +
      geom_segment(
        data = trajectory_data[["edges"]],
        aes(
          source_dim_1,
          source_dim_2,
          xend = target_dim_1,
          yend = target_dim_2
        ),
        size = 0.75,
        linetype = "solid",
        na.rm = TRUE
      ) +
      cerebro_export_theme()

    ## depending on type of cell coloring, add different color scale
    ## ... categorical
    if (
      is.factor(cells_df[[input[["trajectory_point_color"]]]]) ||
        is.character(cells_df[[input[["trajectory_point_color"]]]])
    ) {
      ## get colors for groups
      colors_for_groups <- assignColorsToGroups(
        cells_df,
        input[["trajectory_point_color"]]
      )

      ## add color assignments
      plot <- plot + scale_fill_manual(values = colors_for_groups)

      ## ... not categorical (probably numerical)
    } else {
      ## add continuous color scale
      plot <- plot +
        scale_fill_distiller(
          palette = "Blues",
          direction = 1,
          guide = guide_colorbar(frame.colour = "black", ticks.colour = "black")
        )
    }

    ## render the plot straight into the download stream (device must be set
    ## explicitly: the tempfile Shiny hands us has no .pdf extension to infer).
    ggsave(file, plot, height = 8, width = 11, device = "pdf")
  }
)
