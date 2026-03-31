##----------------------------------------------------------------------------##
## Cell meta data and position in projection.
##----------------------------------------------------------------------------##
overview_projection_data <- reactive({
  req(overview_projection_cells_to_show())
  # message('--> trigger "overview_projection_data"')
  ## Optimization: Only select necessary columns if possible, but for now just optimize subsetting
  ## Use the integer indices directly which is faster than barcode matching or full DF copies
  indices <- overview_projection_cells_to_show()
  
  ## Check if indices are valid
  if (length(indices) == 0) {
    return(getMetaData()[0, ])
  }
  
  cells_df <- getMetaData()[indices, , drop = FALSE]
  # message(str(cells_df))
  return(cells_df)
})
