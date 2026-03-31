##----------------------------------------------------------------------------##
## Indices of cells to show in projection.
##----------------------------------------------------------------------------##
overview_projection_cells_to_show <- reactive({
  req(input[["overview_projection_percentage_cells_to_show"]])
  # message('--> trigger "overview_projection_cells_to_show"')
  groups <- getGroups()

  ## require group filters UI elements
  for ( i in groups ) {
    req(input[[paste0("overview_projection_group_filter_", i)]])
  }

  pct_cells <- input[["overview_projection_percentage_cells_to_show"]]

  ## Get metadata with row indices directly
  cells_df <- getMetaData()
  valid_indices <- seq_len(nrow(cells_df))

  ## Apply filters iteratively using logical indexing
  for ( i in groups ) {
    if ( i %in% colnames(cells_df) ) {
      selected_groups <- input[[paste0("overview_projection_group_filter_", i)]]
      ## Only filter if not all groups are selected (optimization)
      if (!is.null(selected_groups) && length(selected_groups) < length(unique(cells_df[[i]]))) {
         keep <- cells_df[[i]] %in% selected_groups
         valid_indices <- valid_indices[keep[valid_indices]]
      }
    }
  }

  ## Subset using indices
  if (length(valid_indices) < nrow(cells_df)) {
    cells_df_subset <- cells_df[valid_indices, , drop = FALSE]
  } else {
    cells_df_subset <- cells_df
  }

  ## randomly remove cells (if necessary)
  ## Note: randomlySubsetCells likely expects a dataframe and returns a dataframe
  ## We need to ensure we track the original indices

  if (pct_cells < 100) {
    n_to_keep <- ceiling(nrow(cells_df_subset) * (pct_cells / 100))
    if (n_to_keep > 0) {
       sampled_indices <- sample(valid_indices, n_to_keep)
       valid_indices <- sampled_indices
    } else {
       valid_indices <- integer(0)
    }
  }

  ## put rows in random order for plotting (avoid overplotting bias)
  if (length(valid_indices) > 0) {
    valid_indices <- sample(valid_indices)
  }

  return(valid_indices)
})
